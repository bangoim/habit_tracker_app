import os
import traceback
import datetime
from flask import Flask, request, jsonify
from flask_mysqldb import MySQL

app = Flask(__name__)

# Configurações do Banco de Dados
app.config['MYSQL_HOST'] = os.environ.get('MYSQL_HOST', 'localhost')
app.config['MYSQL_USER'] = os.environ.get('MYSQL_USER', 'root')
app.config['MYSQL_PASSWORD'] = os.environ.get('MYSQL_PASSWORD', 'admin') # Mude para sua senha real!
app.config['MYSQL_DB'] = os.environ.get('MYSQL_DB', 'habit_tracker')

mysql = MySQL(app)

# Função auxiliar para calcular a streak
def calculate_streak(completed_dates_raw):
    """Calcula a streak consecutiva com base em uma lista de datas de conclusão.
    As datas devem vir ordenadas da mais recente para a mais antiga.
    """
    if not completed_dates_raw:
        return 0

    # Converte as datas de date objects ou strings para datetime.date objects e ordena de forma decrescente
    completed_dates = sorted(
        [d if isinstance(d, datetime.date) else datetime.date.fromisoformat(str(d)) for d in completed_dates_raw],
        reverse=True
    )
    
    current_streak = 0
    today = datetime.date.today()
    yesterday = today - datetime.timedelta(days=1)

    # Checa se o hábito foi completado hoje
    if completed_dates[0] == today:
        current_streak = 1
        compare_date = yesterday
    elif completed_dates[0] == yesterday: # Se não foi hoje, mas foi ontem
        current_streak = 1
        compare_date = yesterday - datetime.timedelta(days=1)
    else: # Se a data mais recente não é hoje nem ontem, não há streak
        return 0

    # Itera sobre as datas restantes para verificar a consecutividade
    for i in range(1, len(completed_dates)):
        if completed_dates[i] == compare_date:
            current_streak += 1
            compare_date -= datetime.timedelta(days=1)
        elif completed_dates[i] < compare_date: # Se a data é mais antiga que a esperada, a streak foi quebrada
            break
        # Se completed_dates[i] > compare_date, significa que há datas duplicadas ou fora de ordem, continue

    return current_streak

@app.route('/habits', methods=['POST'])
def add_habit():
    try:
        data = request.json
        name = data['name']
        count_method = data['count_method']
        completion_method = data['completion_method']
        description = data.get('description')
        target_quantity = data.get('target_quantity')
        target_days_per_week = data.get('target_days_per_week')

        # Validações básicas (pode ser mais robusto)
        if count_method not in ['daily', 'weekly', 'monthly']:
            return jsonify({'error': 'Invalid count_method. Must be daily, weekly, or monthly.'}), 400
        if completion_method not in ['quantity', 'minutes']:
            return jsonify({'error': 'Invalid completion_method. Must be quantity or minutes.'}), 400

        if (completion_method == 'quantity' or completion_method == 'minutes') and target_quantity is None:
            return jsonify({'error': 'target_quantity is required for quantity or minutes completion methods.'}), 400

        if count_method in ['weekly', 'monthly'] and target_days_per_week is None:
            return jsonify({'error': 'target_days_per_week is required for weekly or monthly habits.'}), 400

        cursor = mysql.connection.cursor()
        cursor.execute(
            "INSERT INTO habits (name, description, count_method, completion_method, target_quantity, target_days_per_week) VALUES (%s, %s, %s, %s, %s, %s)",
            (name, description, count_method, completion_method, target_quantity, target_days_per_week)
        )
        mysql.connection.commit()
        
        habit_id = cursor.lastrowid
        cursor.close()
        
        return jsonify({'message': 'Habit added successfully!', 'id': habit_id}), 201
    except KeyError as e:
        return jsonify({'error': f'Missing data: {e}'}), 400
    except Exception as e:
        print(f"Erro no POST /habits: {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/habits', methods=['GET'])
def get_habits():
    try:
        cursor = mysql.connection.cursor()
        
        today = datetime.date.today()
        start_of_week = today - datetime.timedelta(days=today.weekday())
        start_of_month = today.replace(day=1)

        query = """
        SELECT
            h.id,
            h.name,
            h.description,
            h.count_method,
            h.completion_method,
            h.target_quantity,
            h.target_days_per_week,
            h.created_at,
            (SELECT COUNT(*) FROM habit_records hr_today WHERE hr_today.habit_id = h.id AND hr_today.record_date = %s) > 0 AS is_completed_today,
            (SELECT MAX(hr_last.record_date) FROM habit_records hr_last WHERE hr_last.habit_id = h.id) AS last_completed_date,
            COALESCE((SELECT SUM(hr_qty.quantity_completed) FROM habit_records hr_qty WHERE hr_qty.habit_id = h.id AND hr_qty.record_date >= %s AND hr_qty.record_date <= %s), 0) AS current_period_quantity,
            COALESCE((SELECT COUNT(DISTINCT hr_days.record_date) FROM habit_records hr_days WHERE hr_days.habit_id = h.id AND hr_days.record_date >= %s AND hr_days.record_date <= %s), 0) AS current_period_days_completed
        FROM
            habits h
        """
        
        cursor.execute(query, (
            today.isoformat(),
            start_of_week.isoformat(), today.isoformat(),
            start_of_week.isoformat(), today.isoformat(),
        ))
        
        habits = cursor.fetchall()
        
        habits_list = []
        if cursor.description:
            column_names = [desc[0] for desc in cursor.description]
            for habit_tuple in habits:
                habit_dict = dict(zip(column_names, habit_tuple))
                
                habit_dict['is_completed_today'] = bool(habit_dict['is_completed_today'])
                
                if 'last_completed_date' in habit_dict and isinstance(habit_dict['last_completed_date'], datetime.date):
                    habit_dict['last_completed_date'] = habit_dict['last_completed_date'].isoformat()
                
                # Buscar todas as datas de completude para calcular a streak
                habit_id = habit_dict['id']
                record_dates_query = """
                SELECT record_date FROM habit_records WHERE habit_id = %s ORDER BY record_date DESC
                """
                temp_cursor = mysql.connection.cursor()
                temp_cursor.execute(record_dates_query, (habit_id,))
                completed_dates_raw = [row[0] for row in temp_cursor.fetchall()]
                temp_cursor.close()

                # Calcular a streak usando a função auxiliar
                habit_dict['current_streak'] = calculate_streak(completed_dates_raw)
                
                habits_list.append(habit_dict)
        
        cursor.close()
        
        return jsonify(habits_list), 200
    except Exception as e:
        print(f"Erro ao obter hábitos: {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/habit_records', methods=['POST'])
def add_habit_record():
    try:
        data = request.json
        habit_id = data['habit_id']
        record_date_str = data['record_date'] # Ex: 'YYYY-MM-DD'
        quantity_completed = data.get('quantity_completed') # Pode ser nulo se o método não for de quantidade/minutos

        # Validação básica
        if not habit_id or not record_date_str:
            return jsonify({'error': 'habit_id and record_date are required.'}), 400

        # Opcional: Validar se habit_id existe na tabela habits
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            return jsonify({'error': f'Habit with ID {habit_id} not found.'}), 404

        # Tenta inserir o registro de completude
        # A restrição UNIQUE (habit_id, record_date) no MySQL vai evitar duplicatas no mesmo dia.
        # Se a inserção falhar por duplicidade, o DBAPIError será capturado.
        cursor.execute(
            "INSERT INTO habit_records (habit_id, record_date, quantity_completed) VALUES (%s, %s, %s)",
            (habit_id, record_date_str, quantity_completed)
        )
        mysql.connection.commit()

        record_id = cursor.lastrowid
        cursor.close()

        return jsonify({'message': 'Habit record added successfully!', 'id': record_id}), 201
    except Exception as e:
        print(f"Erro ao adicionar registro de hábito: {e}")
        traceback.print_exc()
        if "Duplicate entry" in str(e) and "for key 'habit_id'" in str(e):
            return jsonify({'error': 'Registro para este hábito e data já existe.'}), 409
        return jsonify({'error': str(e)}), 500

# NOVO: Rota para atualizar um hábito existente
@app.route('/habits/<int:habit_id>', methods=['PUT'])
def update_habit(habit_id):
    try:
        data = request.json
        
        # Validação básica: verificar se o hábito existe
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            return jsonify({'error': f'Habit with ID {habit_id} not found.'}), 404
        
        # Constrói a query de atualização dinamicamente
        update_fields = []
        params = []
        
        if 'name' in data:
            update_fields.append("name = %s")
            params.append(data['name'])
        if 'description' in data:
            update_fields.append("description = %s")
            params.append(data['description'])
        if 'count_method' in data:
            update_fields.append("count_method = %s")
            params.append(data['count_method'])
        if 'completion_method' in data:
            update_fields.append("completion_method = %s")
            params.append(data['completion_method'])
        if 'target_quantity' in data:
            update_fields.append("target_quantity = %s")
            params.append(data['target_quantity'])
        if 'target_days_per_week' in data:
            update_fields.append("target_days_per_week = %s")
            params.append(data['target_days_per_week'])
        
        if not update_fields:
            return jsonify({'message': 'No fields to update.'}), 200 # Nada para atualizar

        query = "UPDATE habits SET " + ", ".join(update_fields) + " WHERE id = %s"
        params.append(habit_id)
        
        cursor.execute(query, tuple(params))
        mysql.connection.commit()
        
        cursor.close()
        return jsonify({'message': f'Habit with ID {habit_id} updated successfully!'}), 200
    except Exception as e:
        print(f"Erro ao atualizar hábito (ID: {habit_id}): {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# NOVO: Rota para excluir um hábito
@app.route('/habits/<int:habit_id>', methods=['DELETE'])
def delete_habit(habit_id):
    try:
        cursor = mysql.connection.cursor()
        cursor.execute("DELETE FROM habits WHERE id = %s", (habit_id,))
        mysql.connection.commit()
        
        if cursor.rowcount == 0:
            cursor.close()
            return jsonify({'error': f'Habit with ID {habit_id} not found.'}), 404
        
        cursor.close()
        return jsonify({'message': f'Habit with ID {habit_id} deleted successfully!'}), 200
    except Exception as e:
        print(f"Erro ao excluir hábito (ID: {habit_id}): {e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True)