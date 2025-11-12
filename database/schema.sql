-- ============================================
-- BANK OF VIT - Complete Database Schema
-- ============================================

CREATE DATABASE bank_of_vit;
USE bank_of_vit;

-- ============================================
-- TABLES
-- ============================================

-- Admin Table
CREATE TABLE admin (
    admin_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users Table
CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    aadhar_number VARCHAR(12) UNIQUE NOT NULL,
    pan_number VARCHAR(10) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Accounts Table
CREATE TABLE accounts (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    account_number VARCHAR(16) UNIQUE NOT NULL,
    account_type ENUM('savings', 'current', 'international') NOT NULL,
    balance DECIMAL(15, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'INR',
    status ENUM('pending', 'active', 'suspended', 'closed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by INT,
    approved_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES admin(admin_id)
);

-- Transactions Table
CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    from_account INT,
    to_account INT,
    transaction_type ENUM('deposit', 'withdrawal', 'transfer', 'international_transfer') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    fee DECIMAL(10, 2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'INR',
    description TEXT,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('completed', 'failed', 'pending') DEFAULT 'completed',
    FOREIGN KEY (from_account) REFERENCES accounts(account_id),
    FOREIGN KEY (to_account) REFERENCES accounts(account_id)
);

-- Loans Table
CREATE TABLE loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    account_id INT NOT NULL,
    loan_type ENUM('home', 'education', 'personal', 'vehicle') NOT NULL,
    loan_amount DECIMAL(15, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    tenure_months INT NOT NULL,
    monthly_emi DECIMAL(15, 2),
    total_payable DECIMAL(15, 2),
    status ENUM('pending', 'approved', 'rejected', 'disbursed', 'closed') DEFAULT 'pending',
    purpose TEXT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by INT,
    approved_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (approved_by) REFERENCES admin(admin_id)
);

-- Loan Payments Table
CREATE TABLE loan_payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    loan_id INT NOT NULL,
    payment_amount DECIMAL(15, 2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remaining_balance DECIMAL(15, 2),
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE CASCADE
);

-- Exchange Rates Table
CREATE TABLE exchange_rates (
    rate_id INT PRIMARY KEY AUTO_INCREMENT,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(10, 4) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to generate account number
DELIMITER //
CREATE FUNCTION generate_account_number() 
RETURNS VARCHAR(16)
DETERMINISTIC
BEGIN
    DECLARE acc_num VARCHAR(16);
    DECLARE num_exists INT;
    
    REPEAT
        SET acc_num = CONCAT('VIT', LPAD(FLOOR(RAND() * 10000000000000), 13, '0'));
        SELECT COUNT(*) INTO num_exists FROM accounts WHERE account_number = acc_num;
    UNTIL num_exists = 0
    END REPEAT;
    
    RETURN acc_num;
END//

-- Function to calculate EMI
CREATE FUNCTION calculate_emi(
    principal DECIMAL(15,2), 
    annual_rate DECIMAL(5,2), 
    months INT
) 
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE monthly_rate DECIMAL(10,6);
    DECLARE emi DECIMAL(15,2);
    
    SET monthly_rate = annual_rate / (12 * 100);
    
    IF monthly_rate = 0 THEN
        SET emi = principal / months;
    ELSE
        SET emi = principal * monthly_rate * POWER(1 + monthly_rate, months) / 
                  (POWER(1 + monthly_rate, months) - 1);
    END IF;
    
    RETURN ROUND(emi, 2);
END//

-- Function to get interest rate based on loan type
CREATE FUNCTION get_loan_interest_rate(loan_type_param VARCHAR(20))
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE rate DECIMAL(5,2);
    
    CASE loan_type_param
        WHEN 'home' THEN SET rate = 8.5;
        WHEN 'education' THEN SET rate = 9.0;
        WHEN 'personal' THEN SET rate = 12.5;
        WHEN 'vehicle' THEN SET rate = 10.0;
        ELSE SET rate = 12.0;
    END CASE;
    
    RETURN rate;
END//

-- Function to convert currency
CREATE FUNCTION convert_currency(
    amount DECIMAL(15,2),
    from_curr VARCHAR(3),
    to_curr VARCHAR(3)
)
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    DECLARE converted_amount DECIMAL(15,2);
    DECLARE exchange_rate DECIMAL(10,4);
    
    IF from_curr = to_curr THEN
        RETURN amount;
    END IF;
    
    SELECT rate INTO exchange_rate 
    FROM exchange_rates 
    WHERE from_currency = from_curr AND to_currency = to_curr
    LIMIT 1;
    
    IF exchange_rate IS NULL THEN
        SET exchange_rate = 83.0; -- Default INR to USD rate
    END IF;
    
    SET converted_amount = amount * exchange_rate;
    
    RETURN ROUND(converted_amount, 2);
END//

-- Function to calculate international transfer fee (2% of amount)
CREATE FUNCTION calculate_intl_fee(amount DECIMAL(15,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(amount * 0.02, 2);
END//

DELIMITER ;

-- ============================================
-- PROCEDURES
-- ============================================

DELIMITER //

-- Procedure to register new user
CREATE PROCEDURE register_user(
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255),
    IN p_full_name VARCHAR(100),
    IN p_phone VARCHAR(15),
    IN p_address TEXT,
    IN p_dob DATE,
    IN p_aadhar VARCHAR(12),
    IN p_pan VARCHAR(10),
    OUT p_user_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE user_exists INT;
    DECLARE age INT;
    
    -- Validate age (must be 18+)
    SET age = TIMESTAMPDIFF(YEAR, p_dob, CURDATE());
    
    IF age < 18 THEN
        SET p_user_id = -1;
        SET p_message = 'User must be at least 18 years old';
    ELSE
        -- Check if user already exists
        SELECT COUNT(*) INTO user_exists 
        FROM users 
        WHERE email = p_email OR aadhar_number = p_aadhar OR pan_number = p_pan;
        
        IF user_exists > 0 THEN
            SET p_user_id = -1;
            SET p_message = 'User with this email, Aadhar, or PAN already exists';
        ELSE
            INSERT INTO users (email, password, full_name, phone, address, date_of_birth, aadhar_number, pan_number)
            VALUES (p_email, p_password, p_full_name, p_phone, p_address, p_dob, p_aadhar, p_pan);
            
            SET p_user_id = LAST_INSERT_ID();
            SET p_message = 'User registered successfully';
        END IF;
    END IF;
END//

-- Procedure to create account
CREATE PROCEDURE create_account(
    IN p_user_id INT,
    IN p_account_type VARCHAR(20),
    OUT p_account_id INT,
    OUT p_account_number VARCHAR(16),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE user_exists INT;
    DECLARE acc_num VARCHAR(16);
    DECLARE curr VARCHAR(3);
    
    -- Check if user exists
    SELECT COUNT(*) INTO user_exists FROM users WHERE user_id = p_user_id AND is_active = TRUE;
    
    IF user_exists = 0 THEN
        SET p_account_id = -1;
        SET p_message = 'User not found or inactive';
    ELSE
        -- Generate account number
        SET acc_num = generate_account_number();
        
        -- Set currency based on account type
        IF p_account_type = 'international' THEN
            SET curr = 'USD';
        ELSE
            SET curr = 'INR';
        END IF;
        
        INSERT INTO accounts (user_id, account_number, account_type, currency, status)
        VALUES (p_user_id, acc_num, p_account_type, curr, 'pending');
        
        SET p_account_id = LAST_INSERT_ID();
        SET p_account_number = acc_num;
        SET p_message = 'Account created successfully. Awaiting admin approval.';
    END IF;
END//

-- Procedure to approve account
CREATE PROCEDURE approve_account(
    IN p_account_id INT,
    IN p_admin_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE acc_status VARCHAR(20);
    
    SELECT status INTO acc_status FROM accounts WHERE account_id = p_account_id;
    
    IF acc_status IS NULL THEN
        SET p_message = 'Account not found';
    ELSEIF acc_status != 'pending' THEN
        SET p_message = 'Account is not in pending status';
    ELSE
        UPDATE accounts 
        SET status = 'active', 
            approved_by = p_admin_id, 
            approved_at = CURRENT_TIMESTAMP
        WHERE account_id = p_account_id;
        
        SET p_message = 'Account approved successfully';
    END IF;
END//

-- Procedure for money transfer
CREATE PROCEDURE transfer_money(
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(15,2),
    IN p_description TEXT,
    OUT p_transaction_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE from_balance DECIMAL(15,2);
    DECLARE from_currency VARCHAR(3);
    DECLARE from_status VARCHAR(20);
    DECLARE to_currency VARCHAR(3);
    DECLARE to_status VARCHAR(20);
    DECLARE to_type VARCHAR(20);
    DECLARE converted_amount DECIMAL(15,2);
    DECLARE transfer_fee DECIMAL(10,2) DEFAULT 0.00;
    DECLARE trans_type VARCHAR(30);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_transaction_id = -1;
        SET p_message = 'Transaction failed due to an error';
    END;
    
    START TRANSACTION;
    
    -- Get account details
    SELECT balance, currency, status INTO from_balance, from_currency, from_status
    FROM accounts WHERE account_id = p_from_account FOR UPDATE;
    
    SELECT currency, status, account_type INTO to_currency, to_status, to_type
    FROM accounts WHERE account_id = p_to_account FOR UPDATE;
    
    -- Validate accounts
    IF from_balance IS NULL OR to_currency IS NULL THEN
        ROLLBACK;
        SET p_transaction_id = -1;
        SET p_message = 'Invalid account(s)';
    ELSEIF from_status != 'active' OR to_status != 'active' THEN
        ROLLBACK;
        SET p_transaction_id = -1;
        SET p_message = 'One or both accounts are not active';
    ELSEIF p_amount <= 0 THEN
        ROLLBACK;
        SET p_transaction_id = -1;
        SET p_message = 'Invalid amount';
    ELSE
        -- Check if international transfer
        IF to_type = 'international' AND from_currency = 'INR' THEN
            SET transfer_fee = calculate_intl_fee(p_amount);
            SET converted_amount = convert_currency(p_amount, from_currency, to_currency);
            SET trans_type = 'international_transfer';
        ELSE
            SET converted_amount = p_amount;
            SET trans_type = 'transfer';
        END IF;
        
        -- Check sufficient balance
        IF from_balance < (p_amount + transfer_fee) THEN
            ROLLBACK;
            SET p_transaction_id = -1;
            SET p_message = 'Insufficient balance';
        ELSE
            -- Deduct from sender
            UPDATE accounts 
            SET balance = balance - p_amount - transfer_fee
            WHERE account_id = p_from_account;
            
            -- Add to receiver
            UPDATE accounts 
            SET balance = balance + converted_amount
            WHERE account_id = p_to_account;
            
            -- Record transaction
            INSERT INTO transactions (from_account, to_account, transaction_type, amount, fee, currency, description)
            VALUES (p_from_account, p_to_account, trans_type, p_amount, transfer_fee, from_currency, p_description);
            
            SET p_transaction_id = LAST_INSERT_ID();
            SET p_message = CONCAT('Transfer successful. Fee: ', transfer_fee);
            
            COMMIT;
        END IF;
    END IF;
END//

-- Procedure to apply for loan
CREATE PROCEDURE apply_loan(
    IN p_user_id INT,
    IN p_account_id INT,
    IN p_loan_type VARCHAR(20),
    IN p_loan_amount DECIMAL(15,2),
    IN p_tenure_months INT,
    IN p_purpose TEXT,
    OUT p_loan_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE acc_status VARCHAR(20);
    DECLARE interest_rate DECIMAL(5,2);
    DECLARE monthly_emi DECIMAL(15,2);
    DECLARE total_amount DECIMAL(15,2);
    
    -- Validate account
    SELECT status INTO acc_status 
    FROM accounts 
    WHERE account_id = p_account_id AND user_id = p_user_id;
    
    IF acc_status IS NULL THEN
        SET p_loan_id = -1;
        SET p_message = 'Invalid account';
    ELSEIF acc_status != 'active' THEN
        SET p_loan_id = -1;
        SET p_message = 'Account must be active to apply for loan';
    ELSEIF p_loan_amount <= 0 OR p_tenure_months <= 0 THEN
        SET p_loan_id = -1;
        SET p_message = 'Invalid loan amount or tenure';
    ELSE
        -- Get interest rate
        SET interest_rate = get_loan_interest_rate(p_loan_type);
        
        -- Calculate EMI
        SET monthly_emi = calculate_emi(p_loan_amount, interest_rate, p_tenure_months);
        SET total_amount = monthly_emi * p_tenure_months;
        
        INSERT INTO loans (user_id, account_id, loan_type, loan_amount, interest_rate, 
                          tenure_months, monthly_emi, total_payable, purpose)
        VALUES (p_user_id, p_account_id, p_loan_type, p_loan_amount, interest_rate, 
                p_tenure_months, monthly_emi, total_amount, p_purpose);
        
        SET p_loan_id = LAST_INSERT_ID();
        SET p_message = CONCAT('Loan application submitted. EMI: ₹', monthly_emi);
    END IF;
END//

-- Procedure to approve loan
CREATE PROCEDURE approve_loan(
    IN p_loan_id INT,
    IN p_admin_id INT,
    IN p_approve BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE loan_status VARCHAR(20);
    DECLARE loan_amount DECIMAL(15,2);
    DECLARE acc_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Loan approval failed due to an error';
    END;
    
    START TRANSACTION;
    
    SELECT status, loan_amount, account_id INTO loan_status, loan_amount, acc_id
    FROM loans WHERE loan_id = p_loan_id;
    
    IF loan_status IS NULL THEN
        ROLLBACK;
        SET p_message = 'Loan not found';
    ELSEIF loan_status != 'pending' THEN
        ROLLBACK;
        SET p_message = 'Loan is not in pending status';
    ELSE
        IF p_approve = TRUE THEN
            -- Approve and disburse loan
            UPDATE loans 
            SET status = 'disbursed', 
                approved_by = p_admin_id, 
                approved_at = CURRENT_TIMESTAMP
            WHERE loan_id = p_loan_id;
            
            -- Credit amount to account
            UPDATE accounts 
            SET balance = balance + loan_amount
            WHERE account_id = acc_id;
            
            -- Record transaction
            INSERT INTO transactions (to_account, transaction_type, amount, description)
            VALUES (acc_id, 'deposit', loan_amount, CONCAT('Loan disbursement - Loan ID: ', p_loan_id));
            
            SET p_message = 'Loan approved and amount disbursed';
        ELSE
            -- Reject loan
            UPDATE loans 
            SET status = 'rejected', 
                approved_by = p_admin_id, 
                approved_at = CURRENT_TIMESTAMP
            WHERE loan_id = p_loan_id;
            
            SET p_message = 'Loan rejected';
        END IF;
        
        COMMIT;
    END IF;
END//

-- Procedure to deposit money
CREATE PROCEDURE deposit_money(
    IN p_account_id INT,
    IN p_amount DECIMAL(15,2),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE acc_status VARCHAR(20);
    
    SELECT status INTO acc_status FROM accounts WHERE account_id = p_account_id;
    
    IF acc_status IS NULL THEN
        SET p_message = 'Account not found';
    ELSEIF acc_status != 'active' THEN
        SET p_message = 'Account is not active';
    ELSEIF p_amount <= 0 THEN
        SET p_message = 'Invalid amount';
    ELSE
        UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_account_id;
        
        INSERT INTO transactions (to_account, transaction_type, amount, description)
        VALUES (p_account_id, 'deposit', p_amount, 'Cash deposit');
        
        SET p_message = 'Deposit successful';
    END IF;
END//

DELIMITER ;

-- ============================================
-- TRIGGERS
-- ============================================

DELIMITER //

-- Trigger to validate phone number format
CREATE TRIGGER validate_phone_before_insert
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF LENGTH(NEW.phone) < 10 OR NEW.phone NOT REGEXP '^[0-9]+$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid phone number format';
    END IF;
END//

-- Trigger to validate Aadhar number (12 digits)
CREATE TRIGGER validate_aadhar_before_insert
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF LENGTH(NEW.aadhar_number) != 12 OR NEW.aadhar_number NOT REGEXP '^[0-9]+$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Aadhar number must be exactly 12 digits';
    END IF;
END//

-- Trigger to validate PAN number format
CREATE TRIGGER validate_pan_before_insert
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF NEW.pan_number NOT REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]{1}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid PAN format (Must be: ABCDE1234F)';
    END IF;
END//

-- Trigger to prevent negative balance
CREATE TRIGGER prevent_negative_balance
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF NEW.balance < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Account balance cannot be negative';
    END IF;
END//

-- Trigger to log account status changes
CREATE TRIGGER log_account_status_change
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO transactions (to_account, transaction_type, amount, description)
        VALUES (NEW.account_id, 'deposit', 0, 
                CONCAT('Account status changed from ', OLD.status, ' to ', NEW.status));
    END IF;
END//

DELIMITER ;

-- ============================================
-- INITIAL DATA
-- ============================================

-- Insert admin user (password: admin123)
INSERT INTO admin (email, password, full_name) 
VALUES ('admin@bankvit.com', 'admin123', 'Bank Administrator');

-- Insert exchange rates
INSERT INTO exchange_rates (from_currency, to_currency, rate) VALUES
('INR', 'USD', 0.012),
('USD', 'INR', 83.0),
('INR', 'EUR', 0.011),
('EUR', 'INR', 90.0);

-- ============================================
-- SAMPLE VIEWS FOR REPORTING
-- ============================================

-- View for account summary
CREATE VIEW account_summary AS
SELECT 
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    a.currency,
    a.status,
    u.full_name,
    u.email,
    u.phone,
    COUNT(DISTINCT t.transaction_id) as transaction_count,
    COALESCE(SUM(CASE WHEN t.to_account = a.account_id THEN t.amount ELSE 0 END), 0) as total_credits,
    COALESCE(SUM(CASE WHEN t.from_account = a.account_id THEN t.amount ELSE 0 END), 0) as total_debits
FROM accounts a
JOIN users u ON a.user_id = u.user_id
LEFT JOIN transactions t ON a.account_id = t.from_account OR a.account_id = t.to_account
GROUP BY a.account_id, a.account_number, a.account_type, a.balance, a.currency, 
         a.status, u.full_name, u.email, u.phone;

-- View for loan summary with aggregate functions
CREATE VIEW loan_summary AS
SELECT 
    l.loan_type,
    COUNT(*) as total_loans,
    SUM(l.loan_amount) as total_amount,
    AVG(l.loan_amount) as avg_loan_amount,
    MIN(l.interest_rate) as min_interest_rate,
    MAX(l.interest_rate) as max_interest_rate,
    AVG(l.tenure_months) as avg_tenure
FROM loans l
WHERE l.status IN ('approved', 'disbursed')
GROUP BY l.loan_type
HAVING COUNT(*) > 0;

-- ============================================
-- SAMPLE QUERIES (FOR TESTING)
-- ============================================

-- Example of nested query
DELIMITER //
CREATE PROCEDURE get_top_accounts(IN limit_count INT)
BEGIN
    SELECT 
        a.account_number,
        u.full_name,
        a.balance,
        a.account_type
    FROM accounts a
    JOIN users u ON a.user_id = u.user_id
    WHERE a.balance > (
        SELECT AVG(balance) FROM accounts WHERE status = 'active'
    )
    ORDER BY a.balance DESC
    LIMIT limit_count;
END//
DELIMITER ;

-- Example using GROUP BY and HAVING
DELIMITER //
CREATE PROCEDURE get_transaction_stats()
BEGIN
    SELECT 
        DATE(transaction_date) as date,
        transaction_type,
        COUNT(*) as transaction_count,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount
    FROM transactions
    WHERE status = 'completed'
    GROUP BY DATE(transaction_date), transaction_type
    HAVING transaction_count > 0
    ORDER BY date DESC, transaction_count DESC;
END//
DELIMITER ;

-- Example of JOIN query
DELIMITER //
CREATE PROCEDURE get_user_complete_info(IN p_user_id INT)
BEGIN
    SELECT 
        u.user_id,
        u.full_name,
        u.email,
        u.phone,
        u.address,
        a.account_number,
        a.account_type,
        a.balance,
        a.currency,
        a.status as account_status,
        COUNT(DISTINCT l.loan_id) as total_loans,
        COALESCE(SUM(l.loan_amount), 0) as total_loan_amount
    FROM users u
    LEFT JOIN accounts a ON u.user_id = a.user_id
    LEFT JOIN loans l ON u.user_id = l.user_id
    WHERE u.user_id = p_user_id
    GROUP BY u.user_id, u.full_name, u.email, u.phone, u.address, 
             a.account_number, a.account_type, a.balance, a.currency, a.status;
END//
DELIMITER ;

-- DCL Examples (Grant/Revoke) - Run these as needed
-- GRANT SELECT, INSERT, UPDATE ON bank_of_vit.* TO 'bank_user'@'localhost';
-- REVOKE INSERT ON bank_of_vit.admin FROM 'bank_user'@'localhost';

-- TCL is used within procedures (START TRANSACTION, COMMIT, ROLLBACK)

-- ============================================
-- UTILITY PROCEDURES
-- ============================================

DELIMITER //

CREATE PROCEDURE get_pending_accounts()
BEGIN
    SELECT 
        a.account_id,
        a.account_number,
        a.account_type,
        u.full_name,
        u.email,
        u.phone,
        a.created_at
    FROM accounts a
    JOIN users u ON a.user_id = u.user_id
    WHERE a.status = 'pending'
    ORDER BY a.created_at DESC;
END//

CREATE PROCEDURE get_pending_loans()
BEGIN
    SELECT 
        l.loan_id,
        l.loan_type,
        l.loan_amount,
        l.interest_rate,
        l.tenure_months,
        l.monthly_emi,
        l.purpose,
        u.full_name,
        u.email,
        a.account_number,
        l.applied_at
    FROM loans l
    JOIN users u ON l.user_id = u.user_id
    JOIN accounts a ON l.account_id = a.account_id
    WHERE l.status = 'pending'
    ORDER BY l.applied_at DESC;
END//

CREATE PROCEDURE get_user_transactions(IN p_account_id INT)
BEGIN
    SELECT 
        t.transaction_id,
        t.transaction_type,
        t.amount,
        t.fee,
        t.description,
        t.transaction_date,
        t.status,
        CASE 
            WHEN t.from_account = p_account_id THEN 'Debit'
            WHEN t.to_account = p_account_id THEN 'Credit'
        END as type,
        CASE 
            WHEN t.from_account = p_account_id THEN a2.account_number
            WHEN t.to_account = p_account_id THEN a1.account_number
        END as other_account
    FROM transactions t
    LEFT JOIN accounts a1 ON t.from_account = a1.account_id
    LEFT JOIN accounts a2 ON t.to_account = a2.account_id
    WHERE t.from_account = p_account_id OR t.to_account = p_account_id
    ORDER BY t.transaction_date DESC
    LIMIT 50;
END//

CREATE PROCEDURE get_user_loans(IN p_user_id INT)
BEGIN
    SELECT 
        l.loan_id,
        l.loan_type,
        l.loan_amount,
        l.interest_rate,
        l.tenure_months,
        l.monthly_emi,
        l.total_payable,
        l.status,
        l.purpose,
        a.account_number,
        l.applied_at,
        l.approved_at
    FROM loans l
    JOIN accounts a ON l.account_id = a.account_id
    WHERE l.user_id = p_user_id
    ORDER BY l.applied_at DESC;
END//

DELIMITER ;

-- ============================================
-- END OF SCHEMA
-- ============================================