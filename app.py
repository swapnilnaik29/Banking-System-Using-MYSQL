from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import mysql.connector
from mysql.connector import Error
from datetime import datetime
import os

app = Flask(__name__)
app.secret_key = 'vit_bank_secret_key_2024'

# Database configuration
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': '3306',
    'user': 'root',
    'password': 'password',  # Update with your MySQL password
    'database': 'bank_of_vit'
}


def get_db_connection():
    """Create database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

# ============================================
# HOME ROUTES
# ============================================


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/login')
def login_page():
    return render_template('login.html')


@app.route('/register')
def register_page():
    return render_template('register.html')


@app.route('/admin-login')
def admin_login_page():
    return render_template('admin_login.html')

# ============================================
# AUTH ROUTES
# ============================================


@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT user_id, email, full_name, is_active FROM users WHERE email = %s AND password = %s",
            (email, password)
        )
        user = cursor.fetchone()

        if user and user['is_active']:
            session['user_id'] = user['user_id']
            session['user_name'] = user['full_name']
            session['user_type'] = 'user'
            return jsonify({'success': True, 'message': 'Login successful'})
        else:
            return jsonify({'success': False, 'message': 'Invalid credentials or inactive account'})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin-login', methods=['POST'])
def admin_login():
    data = request.json
    email = data.get('email')
    password = data.get('password')

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT admin_id, email, full_name FROM admin WHERE email = %s AND password = %s",
            (email, password)
        )
        admin = cursor.fetchone()

        if admin:
            session['admin_id'] = admin['admin_id']
            session['admin_name'] = admin['full_name']
            session['user_type'] = 'admin'
            return jsonify({'success': True, 'message': 'Admin login successful'})
        else:
            return jsonify({'success': False, 'message': 'Invalid admin credentials'})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/register', methods=['POST'])
def register():
    data = request.json

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        
        # Call stored procedure
        cursor.callproc('register_user', [
            data.get('email'),
            data.get('password'),
            data.get('full_name'),
            data.get('phone'),
            data.get('address'),
            data.get('dob'),
            data.get('aadhar'),
            data.get('pan'),
            0,  # OUT parameter for user_id
            ''  # OUT parameter for message
        ])

        # Fetch OUT parameters
        cursor.execute("SELECT @_register_user_8, @_register_user_9")
        result = cursor.fetchone()
        conn.commit()

        user_id = result[0] if result else None
        message = result[1] if result else 'Registration failed'

        # Handle None values properly
        if user_id is not None and user_id > 0:
            return jsonify({'success': True, 'message': message, 'user_id': user_id})
        else:
            return jsonify({'success': False, 'message': message or 'Registration failed'})
            
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        if 'cursor' in locals():
            cursor.close()
        if conn:
            conn.close()


@app.route('/api/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'success': True, 'message': 'Logged out successfully'})

# ============================================
# USER DASHBOARD ROUTES
# ============================================


@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login_page'))
    return render_template('user_dashboard.html')


@app.route('/api/user/accounts', methods=['GET'])
def get_user_accounts():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    user_id = session['user_id']
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT account_id, account_number, account_type, balance, 
                   currency, status, created_at
            FROM accounts 
            WHERE user_id = %s
            ORDER BY created_at DESC
        """, (user_id,))
        accounts = cursor.fetchall()

        # Convert datetime to string
        for account in accounts:
            if account['created_at']:
                account['created_at'] = account['created_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'accounts': accounts})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/create-account', methods=['POST'])
def create_account():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    user_id = session['user_id']
    account_type = data.get('account_type')

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        cursor.callproc('create_account', [
            user_id,
            account_type,
            0,   # OUT parameter for account_id
            '',  # OUT parameter for account_number
            ''   # OUT parameter for message
        ])

        # Fetch OUT parameters
        cursor.execute("SELECT @_create_account_2, @_create_account_3, @_create_account_4")
        result = cursor.fetchone()
        conn.commit()

        account_id = result[0] if result else None
        account_number = result[1] if result else None
        message = result[2] if result else 'Account creation failed'

        if account_id and account_id > 0:
            return jsonify({
                'success': True,
                'message': message,
                'account_id': account_id,
                'account_number': account_number
            })
        else:
            return jsonify({'success': False, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/transactions/<int:account_id>', methods=['GET'])
def get_transactions(account_id):
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('get_user_transactions', [account_id])

        transactions = []
        for result in cursor.stored_results():
            transactions = result.fetchall()

        # Convert datetime to string safely
        for trans in transactions:
            if 'transaction_date' in trans and trans['transaction_date']:
                trans['transaction_date'] = trans['transaction_date'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'transactions': transactions})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/transfer', methods=['POST'])
def transfer_money():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    from_account = data.get('from_account')
    to_account_number = data.get('to_account_number')
    amount = data.get('amount')
    description = data.get('description', 'Money transfer')

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)

        # Get to_account_id from account_number
        cursor.execute(
            "SELECT account_id, status FROM accounts WHERE account_number = %s",
            (to_account_number,)
        )
        to_account = cursor.fetchone()

        if not to_account:
            return jsonify({'success': False, 'message': 'Recipient account not found'})

        if to_account['status'] != 'active':
            return jsonify({'success': False, 'message': 'Recipient account is not active'})

        to_account_id = to_account['account_id']

        cursor.callproc('transfer_money', [
            from_account,
            to_account_id,
            amount,
            description,
            0,   # OUT parameter for transaction_id
            ''   # OUT parameter for message
        ])

        # Fetch OUT parameters
        cursor.execute("SELECT @_transfer_money_4, @_transfer_money_5")
        result = cursor.fetchone()
        conn.commit()

        transaction_id = result[0] if result else None
        message = result[1] if result else 'Transfer failed'

        if transaction_id and transaction_id > 0:
            return jsonify({
                'success': True,
                'message': message,
                'transaction_id': transaction_id
            })
        else:
            return jsonify({'success': False, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/deposit', methods=['POST'])
def deposit_money():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    account_id = data.get('account_id')
    amount = data.get('amount')

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        cursor.callproc('deposit_money', [
            account_id,
            amount,
            ''   # OUT parameter for message
        ])

        cursor.execute("SELECT @_deposit_money_2")
        result = cursor.fetchone()
        conn.commit()

        message = result[0] if result else 'Deposit failed'
        return jsonify({'success': True, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/apply-loan', methods=['POST'])
def apply_loan():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    user_id = session['user_id']

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        cursor.callproc('apply_loan', [
            user_id,
            data.get('account_id'),
            data.get('loan_type'),
            data.get('loan_amount'),
            data.get('tenure_months'),
            data.get('purpose'),
            0,   # OUT parameter for loan_id
            ''   # OUT parameter for message
        ])

        # Fetch OUT parameters
        cursor.execute("SELECT @_apply_loan_6, @_apply_loan_7")
        result = cursor.fetchone()
        conn.commit()

        loan_id = result[0] if result else None
        message = result[1] if result else 'Loan application failed'

        if loan_id and loan_id > 0:
            return jsonify({
                'success': True,
                'message': message,
                'loan_id': loan_id
            })
        else:
            return jsonify({'success': False, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/user/loans', methods=['GET'])
def get_user_loans():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    user_id = session['user_id']
    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('get_user_loans', [user_id])

        loans = []
        for result in cursor.stored_results():
            loans = result.fetchall()

        # Convert datetime to string safely
        for loan in loans:
            if 'applied_at' in loan and loan['applied_at']:
                loan['applied_at'] = loan['applied_at'].strftime('%Y-%m-%d %H:%M:%S')
            if 'approved_at' in loan and loan['approved_at']:
                loan['approved_at'] = loan['approved_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'loans': loans})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()

# ============================================
# ADMIN DASHBOARD ROUTES
# ============================================


@app.route('/admin-dashboard')
def admin_dashboard():
    if 'admin_id' not in session:
        return redirect(url_for('admin_login_page'))
    return render_template('admin_dashboard.html')


@app.route('/api/admin/pending-accounts', methods=['GET'])
def get_pending_accounts():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('get_pending_accounts')

        accounts = []
        for result in cursor.stored_results():
            accounts = result.fetchall()

        # Convert datetime to string safely
        for account in accounts:
            if 'created_at' in account and account['created_at']:
                account['created_at'] = account['created_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'accounts': accounts})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/pending-loans', methods=['GET'])
def get_pending_loans():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.callproc('get_pending_loans')

        loans = []
        for result in cursor.stored_results():
            loans = result.fetchall()

        # Convert datetime to string safely
        for loan in loans:
            if 'applied_at' in loan and loan['applied_at']:
                loan['applied_at'] = loan['applied_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'loans': loans})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/approve-account', methods=['POST'])
def approve_account():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    account_id = data.get('account_id')
    admin_id = session['admin_id']

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        cursor.callproc('approve_account', [
            account_id,
            admin_id,
            ''   # OUT parameter for message
        ])

        cursor.execute("SELECT @_approve_account_2")
        result = cursor.fetchone()
        conn.commit()

        message = result[0] if result else 'Approval failed'
        return jsonify({'success': True, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/approve-loan', methods=['POST'])
def approve_loan():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    data = request.json
    loan_id = data.get('loan_id')
    approve = data.get('approve')  # True or False
    admin_id = session['admin_id']

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor()
        cursor.callproc('approve_loan', [
            loan_id,
            admin_id,
            approve,
            ''   # OUT parameter for message
        ])

        cursor.execute("SELECT @_approve_loan_3")
        result = cursor.fetchone()
        conn.commit()

        message = result[0] if result else 'Loan approval failed'
        return jsonify({'success': True, 'message': message})
    except Error as e:
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/all-accounts', methods=['GET'])
def get_all_accounts():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT * FROM account_summary
            ORDER BY account_id DESC
        """)
        accounts = cursor.fetchall()

        return jsonify({'success': True, 'accounts': accounts})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/all-loans', methods=['GET'])
def get_all_loans():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT 
                l.loan_id,
                l.loan_type,
                l.loan_amount,
                l.interest_rate,
                l.tenure_months,
                l.monthly_emi,
                l.status,
                u.full_name,
                u.email,
                a.account_number,
                l.applied_at
            FROM loans l
            JOIN users u ON l.user_id = u.user_id
            JOIN accounts a ON l.account_id = a.account_id
            ORDER BY l.applied_at DESC
        """)
        loans = cursor.fetchall()

        # Convert datetime to string safely
        for loan in loans:
            if 'applied_at' in loan and loan['applied_at']:
                loan['applied_at'] = loan['applied_at'].strftime('%Y-%m-%d %H:%M:%S')

        return jsonify({'success': True, 'loans': loans})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


@app.route('/api/admin/stats', methods=['GET'])
def get_admin_stats():
    if 'admin_id' not in session:
        return jsonify({'success': False, 'message': 'Not authenticated'})

    conn = get_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})

    try:
        cursor = conn.cursor(dictionary=True)

        # Get various statistics using aggregate functions
        cursor.execute("""
            SELECT 
                COUNT(*) as total_users,
                SUM(CASE WHEN is_active = TRUE THEN 1 ELSE 0 END) as active_users
            FROM users
        """)
        user_stats = cursor.fetchone()

        cursor.execute("""
            SELECT 
                COUNT(*) as total_accounts,
                SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_accounts,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_accounts,
                SUM(balance) as total_balance
            FROM accounts
        """)
        account_stats = cursor.fetchone()

        cursor.execute("""
            SELECT 
                COUNT(*) as total_loans,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_loans,
                SUM(CASE WHEN status IN ('approved', 'disbursed') THEN loan_amount ELSE 0 END) as total_loan_amount
            FROM loans
        """)
        loan_stats = cursor.fetchone()

        cursor.execute("""
            SELECT 
                COUNT(*) as total_transactions,
                SUM(amount) as total_transaction_amount
            FROM transactions
            WHERE status = 'completed'
        """)
        transaction_stats = cursor.fetchone()

        stats = {
            'users': user_stats,
            'accounts': account_stats,
            'loans': loan_stats,
            'transactions': transaction_stats
        }

        return jsonify({'success': True, 'stats': stats})
    except Error as e:
        return jsonify({'success': False, 'message': str(e)})
    finally:
        cursor.close()
        conn.close()


if __name__ == '__main__':
    app.run(debug=True, port=5000)