import datetime
import os
import traceback

from flask import Flask, jsonify, request
from flask_mysqldb import MySQL

app = Flask(__name__)

# Configurações do Banco de Dados
app.config["MYSQL_HOST"] = os.environ.get("MYSQL_HOST", "localhost")
app.config["MYSQL_USER"] = os.environ.get("MYSQL_USER", "root")
app.config["MYSQL_PASSWORD"] = os.environ.get("MYSQL_PASSWORD", "root")
app.config["MYSQL_DB"] = os.environ.get("MYSQL_DB", "habit_tracker")
app.config["MYSQL_CURSORCLASS"] = "DictCursor"

mysql = MySQL(app)


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

    # Verifica se o hábito foi completado hoje ou ontem para iniciar a contagem
    if completed_dates[0] == today:
        current_streak = 1
        compare_date = yesterday
    elif completed_dates[0] == yesterday:
        current_streak = 1
        compare_date = yesterday - datetime.timedelta(days=1)
    else:
        # Se não foi completado nem hoje nem ontem, a streak é 0
        return 0

    # Continua a contagem para os dias anteriores
    for i in range(1, len(completed_dates)):
        if completed_dates[i] == compare_date:
            current_streak += 1
            compare_date -= datetime.timedelta(days=1)
        elif completed_dates[i] < compare_date:
            # Houve uma quebra na sequência
            break
    return current_streak


@app.route("/categories", methods=["GET"])
def get_all_categories():
    try:
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id, name FROM categories ORDER BY name ASC")
        categories = cursor.fetchall()
        cursor.close()
        return jsonify(categories), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify(
            {"error": "Erro interno ao buscar categorias", "details": str(e)}
        ), 500


@app.route("/habits", methods=["POST"])
def add_habit():
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
                cursor.execute(
                    "INSERT INTO habit_categories (habit_id, category_id) VALUES (%s, %s)",
                    (habit_id, category_id),
                )
        mysql.connection.commit()
        cursor.close()
        return jsonify({"message": "Habit added successfully!", "id": habit_id}), 201
    except KeyError as e:
        traceback.print_exc()
        return jsonify({"error": f"Missing data: {e}"}), 400
    except Exception as e:
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habits", methods=["GET"])
def get_habits():
    try:
        cursor = mysql.connection.cursor()
        today = datetime.date.today()

        # Determina o início do período (semana ou mês) com base no count_method (exemplo simplificado para semanal)
        # Para uma lógica mais precisa de período, você precisaria ajustar isso conforme o count_method
        # Por ora, current_period_quantity e current_period_days_completed usam a semana atual.
        start_of_current_period = today - datetime.timedelta(
            days=today.weekday()
        )  # Início da semana atual (segunda-feira)

        base_query = """
            SELECT
                h.id, h.name, h.description, h.count_method, h.completion_method,
                h.target_quantity, h.target_days_per_week, h.created_at,
                (SELECT COUNT(*) FROM habit_records hr_today WHERE hr_today.habit_id = h.id AND hr_today.record_date = %s) > 0 AS is_completed_today,
                (SELECT MAX(hr_last.record_date) FROM habit_records hr_last WHERE hr_last.habit_id = h.id) AS last_completed_date,
                COALESCE((
                    SELECT SUM(hr_qty.quantity_completed)
                    FROM habit_records hr_qty
                    WHERE hr_qty.habit_id = h.id
                      AND hr_qty.record_date >= %s -- início do período atual
                      AND hr_qty.record_date <= %s -- data de hoje
                ), 0) AS current_period_quantity,
                COALESCE((
                    SELECT COUNT(DISTINCT hr_days.record_date)
                    FROM habit_records hr_days
                    WHERE hr_days.habit_id = h.id
                      AND hr_days.record_date >= %s -- início do período atual
                      AND hr_days.record_date <= %s -- data de hoje
                ), 0) AS current_period_days_completed
            FROM habits h
        """

        query_params_dates = [
            today.isoformat(),
            start_of_current_period.isoformat(),  # Para current_period_quantity
            today.isoformat(),  # Para current_period_quantity
            start_of_current_period.isoformat(),  # Para current_period_days_completed
            today.isoformat(),  # Para current_period_days_completed
        ]

        filter_category_id = request.args.get("category_id", type=int)
        final_query_params = list(query_params_dates)

        if filter_category_id:
            base_query += """
                JOIN habit_categories hc ON h.id = hc.habit_id
                WHERE hc.category_id = %s
            """
            final_query_params.append(filter_category_id)

        base_query += " ORDER BY h.created_at DESC"

        cursor.execute(base_query, tuple(final_query_params))
        habits_results = cursor.fetchall()

        for habit in habits_results:
            cat_cursor = mysql.connection.cursor()
            cat_cursor.execute(
                """
                SELECT c.id, c.name FROM categories c
                JOIN habit_categories hc ON c.id = hc.category_id
                WHERE hc.habit_id = %s
            """,
                (habit["id"],),
            )
            habit["categories"] = cat_cursor.fetchall()
            cat_cursor.close()

            streak_cursor = mysql.connection.cursor()
            if habit["completion_method"] == "boolean":
                streak_cursor.execute(
                    "SELECT DISTINCT record_date FROM habit_records WHERE habit_id = %s ORDER BY record_date DESC",
                    (habit["id"],),
                )
            elif (
                habit["completion_method"] in ["quantity", "minutes"]
                and habit["target_quantity"] is not None
                and habit["target_quantity"] > 0
            ):
                streak_cursor.execute(
                    """
                    SELECT record_date
                    FROM (
                        SELECT record_date, SUM(quantity_completed) as total_quantity_today
                        FROM habit_records
                        WHERE habit_id = %s
                        GROUP BY record_date
                    ) AS daily_totals
                    WHERE daily_totals.total_quantity_today >= %s
                    ORDER BY record_date DESC
                    """,
                    (habit["id"], habit["target_quantity"]),
                )
            else:
                streak_cursor.execute(
                    "SELECT DISTINCT record_date FROM habit_records WHERE habit_id = %s ORDER BY record_date DESC",
                    (habit["id"],),
                )

            completed_dates_raw_dicts = streak_cursor.fetchall()
            completed_dates_raw = [
                row["record_date"] for row in completed_dates_raw_dicts
            ]
            streak_cursor.close()
            habit["current_streak"] = calculate_streak(completed_dates_raw)

            habit["is_completed_today"] = bool(habit["is_completed_today"])
            if isinstance(habit.get("last_completed_date"), datetime.date):
                habit["last_completed_date"] = habit["last_completed_date"].isoformat()
            if isinstance(
                habit.get("created_at"), datetime.datetime
            ):  # Assegura que created_at seja string
                habit["created_at"] = habit["created_at"].isoformat()

        cursor.close()
        return jsonify(habits_results), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/habits/<int:habit_id>", methods=["PUT"])
def update_habit(habit_id):
    try:
        data = request.json
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404

        update_fields_habits = []
        params_habits = []
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
            cursor.execute(query_habits, tuple(params_habits))

        if "category_ids" in data:
            new_category_ids = data.get("category_ids", [])
            cursor.execute(
                "DELETE FROM habit_categories WHERE habit_id = %s", (habit_id,)
            )
            if isinstance(new_category_ids, list):
                for category_id in new_category_ids:
                    cursor.execute(
                        "INSERT INTO habit_categories (habit_id, category_id) VALUES (%s, %s)",
                        (habit_id, category_id),
                    )
        mysql.connection.commit()
        cursor.close()
        return jsonify(
            {"message": f"Habit with ID {habit_id} updated successfully!"}
        ), 200
    except Exception as e:
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habits/<int:habit_id>", methods=["DELETE"])
def delete_habit(habit_id):
    try:
        cursor = mysql.connection.cursor()
        cursor.execute("DELETE FROM habits WHERE id = %s", (habit_id,))
        mysql.connection.commit()
        if cursor.rowcount == 0:
            cursor.close()
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404
        cursor.close()
        return jsonify(
            {"message": f"Habit with ID {habit_id} deleted successfully!"}
        ), 200
    except Exception as e:
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habit_records", methods=["POST"])
def add_habit_record():
    try:
        data = request.json
        habit_id = data["habit_id"]
        record_date_str = data["record_date"]
        quantity_to_add = data.get("quantity_completed", 1)

        if not habit_id or not record_date_str:
            return jsonify({"error": "habit_id and record_date are required."}), 400

        cursor = mysql.connection.cursor()
        cursor.execute(
            "SELECT id, completion_method FROM habits WHERE id = %s", (habit_id,)
        )
        habit_info = cursor.fetchone()
        if not habit_info:
            cursor.close()
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404

        if habit_info["completion_method"] == "boolean":
            sql = """
                INSERT INTO habit_records (habit_id, record_date, quantity_completed)
                VALUES (%s, %s, 1)
                ON DUPLICATE KEY UPDATE created_at = CURRENT_TIMESTAMP
            """
            params = (habit_id, record_date_str)
        else:
            sql = """
                INSERT INTO habit_records (habit_id, record_date, quantity_completed)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE quantity_completed = quantity_completed + VALUES(quantity_completed),
                                       created_at = CURRENT_TIMESTAMP
            """
            params = (habit_id, record_date_str, quantity_to_add)

        cursor.execute(sql, params)
        mysql.connection.commit()
        record_id = cursor.lastrowid
        cursor.close()
        return jsonify(
            {"message": "Habit record added/updated successfully!", "id": record_id}
        ), 201
    except Exception as e:
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify({"error": str(e)}), 500


@app.route("/habit_records/today", methods=["DELETE"])
def delete_habit_record_today():
    habit_id = request.args.get("habit_id", type=int)
    record_date_str = datetime.date.today().isoformat()
    if not habit_id:
        return jsonify({"error": "habit_id is required as a query parameter."}), 400
    try:
        cursor = mysql.connection.cursor()
        cursor.execute("SELECT id FROM habits WHERE id = %s", (habit_id,))
        if not cursor.fetchone():
            cursor.close()
            return jsonify({"error": f"Habit with ID {habit_id} not found."}), 404
        result = cursor.execute(
            "DELETE FROM habit_records WHERE habit_id = %s AND record_date = %s",
            (habit_id, record_date_str),
        )
        mysql.connection.commit()
        cursor.close()
        if result > 0:
            return jsonify(
                {
                    "message": f"Habit record for habit {habit_id} on {record_date_str} deleted successfully."
                }
            ), 200
        else:
            return jsonify(
                {
                    "message": f"No habit record found for habit {habit_id} on {record_date_str} to delete."
                }
            ), 200
    except Exception as e:
        traceback.print_exc()
        mysql.connection.rollback()
        return jsonify(
            {"error": "Failed to delete habit record for today.", "details": str(e)}
        ), 500


@app.route("/habits/<int:habit_id>/records", methods=["GET"])
def get_habit_records_for_heatmap(habit_id):
    try:
        start_date_str = request.args.get("start_date")
        end_date_str = request.args.get("end_date")
        cursor = mysql.connection.cursor()
        query = "SELECT record_date, quantity_completed FROM habit_records WHERE habit_id = %s"
        params = [habit_id]
        if start_date_str:
            query += " AND record_date >= %s"
            params.append(start_date_str)
        if end_date_str:
            query += " AND record_date <= %s"
            params.append(end_date_str)
        query += " ORDER BY record_date ASC"
        cursor.execute(query, tuple(params))
        records = cursor.fetchall()
        cursor.close()
        formatted_records = [
            {
                "record_date": record["record_date"].isoformat(),
                "quantity_completed": record["quantity_completed"],
            }
            for record in records
        ]
        return jsonify(formatted_records), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/all_habit_records", methods=["GET"])
def get_all_habit_records_for_heatmap():
    try:
        start_date_str = request.args.get("start_date")
        end_date_str = request.args.get("end_date")
        cursor = mysql.connection.cursor()
        query = "SELECT habit_id, record_date, quantity_completed FROM habit_records"
        params = []
        where_clauses = []
        if start_date_str:
            where_clauses.append("record_date >= %s")
            params.append(start_date_str)
        if end_date_str:
            where_clauses.append("record_date <= %s")
            params.append(end_date_str)
        if where_clauses:
            query += " WHERE " + " AND ".join(where_clauses)
        query += " ORDER BY record_date ASC"
        cursor.execute(query, tuple(params))
        records = cursor.fetchall()
        cursor.close()
        formatted_records = [
            {
                "habit_id": record["habit_id"],
                "record_date": record["record_date"].isoformat(),
                "quantity_completed": record["quantity_completed"],
            }
            for record in records
        ]
        return jsonify(formatted_records), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
