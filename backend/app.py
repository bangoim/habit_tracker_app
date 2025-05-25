import datetime
import os
import traceback

from flask import Flask, jsonify, request
from flask_mysqldb import MySQL

app = Flask(__name__)

# Configurações do Banco de Dados
app.config["MYSQL_HOST"] = os.environ.get("MYSQL_HOST", "localhost")
app.config["MYSQL_USER"] = os.environ.get("MYSQL_USER", "root")
app.config["MYSQL_PASSWORD"] = os.environ.get("MYSQL_PASSWORD", "root")  # Sua senha
app.config["MYSQL_DB"] = os.environ.get("MYSQL_DB", "habit_tracker")

# ADICIONE ESTA LINHA: Para que os cursores retornem dicionários por padrão
app.config["MYSQL_CURSORCLASS"] = "DictCursor"

mysql = MySQL(app)


# Função auxiliar para calcular a streak
def calculate_streak(completed_dates_raw):
    if not completed_dates_raw:
        return 0
    completed_dates = sorted(
        [
            d if isinstance(d, datetime.date) else datetime.date.fromisoformat(str(d))
            for d in completed_dates_raw
        ],
        reverse=True,
    )
    current_streak = 0
    today = datetime.date.today()
    yesterday = today - datetime.timedelta(days=1)
    if not completed_dates:
        return 0
    if completed_dates[0] == today:
        current_streak = 1
        compare_date = yesterday
    elif completed_dates[0] == yesterday:
        current_streak = 1
        compare_date = yesterday - datetime.timedelta(days=1)
    else:
        return 0
    for i in range(1, len(completed_dates)):
        if completed_dates[i] == compare_date:
            current_streak += 1
            compare_date -= datetime.timedelta(days=1)
        elif completed_dates[i] < compare_date:
            break
    return current_streak


@app.route("/categories", methods=["GET"])
def get_all_categories():
    print("LOG: Rota /categories foi chamada")
    try:
        # REMOVA dictionary=True daqui
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id, name FROM categories ORDER BY name ASC")
        categories = cursor.fetchall()
        cursor.close()
        print(f"LOG: Categorias encontradas: {categories}")
        return jsonify(categories), 200
    except Exception as e:
        print(f"LOG: Erro ao obter categorias: {e}")
        traceback.print_exc()
        return jsonify(
            {"error": "Erro interno ao buscar categorias", "details": str(e)}
        ), 500


@app.route("/habits", methods=["POST"])
def add_habit():
    print("LOG: Rota POST /habits foi chamada")
    try:
        data = request.json
        name = data["name"]
        count_method = data["count_method"]
        completion_method = data["completion_method"]
        description = data.get("description")
        target_quantity = data.get("target_quantity")
        target_days_per_week = data.get("target_days_per_week")
        category_ids = data.get("category_ids", [])

        if not name:
            return jsonify({"error": "Name is required"}), 400
        # Adicione outras validações aqui se necessário

        # REMOVA dictionary=True daqui (se estivesse aqui)
        cursor = mysql.connection.cursor()
        cursor.execute(
            "INSERT INTO habits (name, description, count_method, completion_method, target_quantity, target_days_per_week) VALUES (%s, %s, %s, %s, %s, %s)",
            (
                name,
                description,
                count_method,
                completion_method,
                target_quantity,
                target_days_per_week,
            ),
        )
        habit_id = cursor.lastrowid

        if isinstance(category_ids, list):
            for category_id in category_ids:
                try:
                    cursor.execute(
                        "INSERT INTO habit_categories (habit_id, category_id) VALUES (%s, %s)",
                        (habit_id, category_id),
                    )
                except Exception as e:
                    print(
                        f"Erro ao associar categoria {category_id} ao hábito {habit_id}: {e}"
                    )
                    # Considere se deve dar rollback aqui ou apenas logar

        mysql.connection.commit()
        cursor.close()
        print(f"LOG: Hábito adicionado com ID: {habit_id}")
        return jsonify({"message": "Habit added successfully!", "id": habit_id}), 201
    except KeyError as e:
        print(f"LOG: Erro no POST /habits - Missing data: {e}")
        traceback.print_exc()
        return jsonify({"error": f"Missing data: {e}"}), 400
    except Exception as e:
        print(f"LOG: Erro no POST /habits: {e}")
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habits", methods=["GET"])
def get_habits():
    print("LOG: Rota GET /habits foi chamada")
    try:
        # REMOVA dictionary=True daqui
        cursor = mysql.connection.cursor()
        today = datetime.date.today()
        start_of_week = today - datetime.timedelta(days=today.weekday())

        base_query = """
            SELECT
                h.id, h.name, h.description, h.count_method, h.completion_method,
                h.target_quantity, h.target_days_per_week, h.created_at,
                (SELECT COUNT(*) FROM habit_records hr_today WHERE hr_today.habit_id = h.id AND hr_today.record_date = %s) > 0 AS is_completed_today,
                (SELECT MAX(hr_last.record_date) FROM habit_records hr_last WHERE hr_last.habit_id = h.id) AS last_completed_date,
                COALESCE((SELECT SUM(hr_qty.quantity_completed) FROM habit_records hr_qty WHERE hr_qty.habit_id = h.id AND hr_qty.record_date >= %s AND hr_qty.record_date <= %s), 0) AS current_period_quantity,
                COALESCE((SELECT COUNT(DISTINCT hr_days.record_date) FROM habit_records hr_days WHERE hr_days.habit_id = h.id AND hr_days.record_date >= %s AND hr_days.record_date <= %s), 0) AS current_period_days_completed
            FROM habits h
        """

        query_params_dates = [
            today.isoformat(),
            start_of_week.isoformat(),
            today.isoformat(),
            start_of_week.isoformat(),
            today.isoformat(),
        ]

        filter_category_id = request.args.get("category_id", type=int)
        final_query_params = list(query_params_dates)

        # Adiciona o JOIN e o WHERE para filtrar por categoria apenas se filter_category_id for fornecido
        # E garante que a query principal não tenha um WHERE antes disso que possa causar conflito.
        # Se filter_category_id for o único critério de filtro principal na tabela 'h', esta abordagem é correta.
        if filter_category_id:
            # Modifica a query para buscar apenas hábitos que tenham a categoria especificada
            # Precisamos garantir que 'h' seja o alias correto e que o JOIN não duplique hábitos
            # se um hábito puder estar em múltiplas categorias (o que não é o caso aqui se filtrarmos por UMA categoria_id)
            # No entanto, para retornar TODOS os hábitos e depois filtrar no frontend, não adicionamos o JOIN aqui.
            # Se o objetivo é filtrar NO BACKEND, a query precisa ser ajustada.
            # A query atual com JOIN + WHERE retornaria hábitos que correspondem à categoria.
            # Vamos manter o filtro no backend como está.
            base_query += """
                JOIN habit_categories hc ON h.id = hc.habit_id
                WHERE hc.category_id = %s
            """
            final_query_params.append(filter_category_id)

        base_query += " ORDER BY h.created_at DESC"

        print(f"LOG: Executando query de hábitos com params: {final_query_params}")
        cursor.execute(base_query, tuple(final_query_params))
        habits_results = cursor.fetchall()
        print(
            f"LOG: Hábitos encontrados (antes de adicionar categorias e streak): {len(habits_results)}"
        )

        for habit in habits_results:  # 'habit' agora é um dicionário
            # REMOVA dictionary=True daqui
            cat_cursor = mysql.connection.cursor()
            cat_cursor.execute(
                """
                SELECT c.id, c.name FROM categories c
                JOIN habit_categories hc ON c.id = hc.category_id
                WHERE hc.habit_id = %s
            """,
                (habit["id"],),  # Acesso por chave, pois habit é um dicionário
            )
            habit["categories"] = cat_cursor.fetchall()
            cat_cursor.close()

            # REMOVA dictionary=True daqui
            streak_cursor = mysql.connection.cursor()
            streak_cursor.execute(
                "SELECT record_date FROM habit_records WHERE habit_id = %s ORDER BY record_date DESC",
                (habit["id"],),
            )
            # Com MYSQL_CURSORCLASS = 'DictCursor', fetchall() retorna [{ 'record_date': ...}, ...]
            completed_dates_raw_dicts = streak_cursor.fetchall()
            completed_dates_raw = [
                row["record_date"] for row in completed_dates_raw_dicts
            ]
            streak_cursor.close()
            habit["current_streak"] = calculate_streak(completed_dates_raw)

            habit["is_completed_today"] = bool(habit["is_completed_today"])
            if isinstance(habit.get("last_completed_date"), datetime.date):
                habit["last_completed_date"] = habit["last_completed_date"].isoformat()

        cursor.close()
        print(f"LOG: Retornando {len(habits_results)} hábitos processados.")
        return jsonify(habits_results), 200
    except Exception as e:
        print(f"LOG: Erro ao obter hábitos: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/habits/<int:habit_id>", methods=["PUT"])
def update_habit(habit_id):
    print(f"LOG: Rota PUT /habits/{habit_id} foi chamada")
    try:
        data = request.json
        # REMOVA dictionary=True daqui
        cursor = mysql.connection.cursor()

        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404

        update_fields_habits = []
        params_habits = []

        # Campos do hábito a serem atualizados
        allowed_fields = [
            "name",
            "description",
            "count_method",
            "completion_method",
            "target_quantity",
            "target_days_per_week",
        ]
        for field in allowed_fields:
            if field in data:
                update_fields_habits.append(f"{field} = %s")
                params_habits.append(data[field])

        if update_fields_habits:
            query_habits = (
                "UPDATE habits SET "
                + ", ".join(update_fields_habits)
                + " WHERE id = %s"
            )
            params_habits.append(habit_id)
            print(
                f"LOG: Atualizando hábito {habit_id} com query: {query_habits} e params: {params_habits}"
            )
            cursor.execute(query_habits, tuple(params_habits))

        if "category_ids" in data:
            new_category_ids = data.get("category_ids", [])
            print(
                f"LOG: Atualizando categorias para hábito {habit_id} com IDs: {new_category_ids}"
            )
            cursor.execute(
                "DELETE FROM habit_categories WHERE habit_id = %s", (habit_id,)
            )
            if isinstance(new_category_ids, list):
                for category_id in new_category_ids:
                    try:
                        cursor.execute(
                            "INSERT INTO habit_categories (habit_id, category_id) VALUES (%s, %s)",
                            (habit_id, category_id),
                        )
                    except Exception as e:
                        print(
                            f"Erro ao associar categoria {category_id} na atualização do hábito {habit_id}: {e}"
                        )

        mysql.connection.commit()
        cursor.close()
        print(f"LOG: Hábito {habit_id} atualizado com sucesso.")
        return jsonify(
            {"message": f"Habit with ID {habit_id} updated successfully!"}
        ), 200
    except Exception as e:
        print(f"LOG: Erro ao atualizar hábito (ID: {habit_id}): {e}")
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habits/<int:habit_id>", methods=["DELETE"])
def delete_habit(habit_id):
    print(f"LOG: Rota DELETE /habits/{habit_id} foi chamada")
    try:
        # REMOVA dictionary=True daqui
        cursor = mysql.connection.cursor()
        cursor.execute("DELETE FROM habits WHERE id = %s", (habit_id,))
        mysql.connection.commit()

        if cursor.rowcount == 0:
            cursor.close()
            print(f"LOG: Hábito {habit_id} não encontrado para exclusão.")
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404

        cursor.close()
        print(f"LOG: Hábito {habit_id} excluído com sucesso.")
        return jsonify(
            {"message": f"Habit with ID {habit_id} deleted successfully!"}
        ), 200
    except Exception as e:
        print(f"LOG: Erro ao excluir hábito (ID: {habit_id}): {e}")
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habit_records", methods=["POST"])
def add_habit_record():
    print("LOG: Rota POST /habit_records foi chamada")
    try:
        data = request.json
        habit_id = data["habit_id"]
        record_date_str = data["record_date"]
        quantity_completed = data.get("quantity_completed")

        if not habit_id or not record_date_str:
            return jsonify({"error": "habit_id and record_date are required."}), 400

        # REMOVA dictionary=True daqui
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            print(f"LOG: Hábito {habit_id} não encontrado para adicionar registro.")
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404

        cursor.execute(
            "INSERT INTO habit_records (habit_id, record_date, quantity_completed) VALUES (%s, %s, %s)",
            (habit_id, record_date_str, quantity_completed),
        )
        mysql.connection.commit()
        record_id = cursor.lastrowid
        cursor.close()
        print(
            f"LOG: Registro de hábito adicionado com ID: {record_id} para o hábito {habit_id}"
        )
        return jsonify(
            {"message": "Habit record added successfully!", "id": record_id}
        ), 201
    except Exception as e:
        print(f"LOG: Erro ao adicionar registro de hábito: {e}")
        traceback.print_exc()
        if (
            "Duplicate entry"
            in str(
                e
            )  # Checagem genérica, ideal seria pelo código de erro do MySQL para duplicidade
            # and "for key 'habit_records.habit_id_record_date_unique'" in str(e).lower() # Esta parte é muito específica
        ):
            return jsonify(
                {"error": "Registro para este hábito e data já existe."}
            ), 409
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    print("LOG: Iniciando servidor Flask...")
    app.run(host="0.0.0.0", port=5000, debug=True)
