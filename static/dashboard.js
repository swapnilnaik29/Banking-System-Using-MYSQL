// Tab functionality
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(tabName + 'Tab').classList.add('active');
    event.target.classList.add('active');
}

// Modal functions
function showCreateAccountModal() {
    document.getElementById('createAccountModal').classList.add('active');
}

function showApplyLoanModal() {
    loadActiveAccounts('loanAccount');
    document.getElementById('applyLoanModal').classList.add('active');
}

function showDepositModal(accountId) {
    document.getElementById('depositAccountId').value = accountId;
    document.getElementById('depositModal').classList.add('active');
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}

// Logout function
async function logout() {
    const response = await fetch('/api/logout', { method: 'POST' });
    if (response.ok) {
        window.location.href = '/login';
    }
}

// Load accounts
async function loadAccounts() {
    try {
        const response = await fetch('/api/user/accounts');
        const data = await response.json();
        
        if (data.success) {
            displayAccounts(data.accounts);
            updateStats(data.accounts);
            populateAccountSelects(data.accounts);
        }
    } catch (error) {
        console.error('Error loading accounts:', error);
    }
}

function displayAccounts(accounts) {
    const container = document.getElementById('accountsList');
    
    if (accounts.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📭</div>
                <p>No accounts found. Create your first account!</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = `
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Account Number</th>
                        <th>Type</th>
                        <th>Balance</th>
                        <th>Currency</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${accounts.map(acc => `
                        <tr>
                            <td>${acc.account_number}</td>
                            <td style="text-transform: capitalize;">${acc.account_type}</td>
                            <td>${acc.currency} ${parseFloat(acc.balance).toFixed(2)}</td>
                            <td>${acc.currency}</td>
                            <td><span class="badge badge-${acc.status}">${acc.status}</span></td>
                            <td>
                                ${acc.status === 'active' ? 
                                    `<button class="btn btn-success" style="padding: 0.5rem 1rem; font-size: 0.875rem;" onclick="showDepositModal(${acc.account_id})">Deposit</button>` 
                                    : '-'}
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

function updateStats(accounts) {
    const totalAccounts = accounts.length;
    const activeAccounts = accounts.filter(a => a.status === 'active').length;
    const totalBalance = accounts.reduce((sum, acc) => sum + parseFloat(acc.balance), 0);
    
    document.getElementById('statsContainer').innerHTML = `
        <div class="stat-card">
            <h3>Total Accounts</h3>
            <div class="stat-value">${totalAccounts}</div>
        </div>
        <div class="stat-card">
            <h3>Active Accounts</h3>
            <div class="stat-value">${activeAccounts}</div>
        </div>
        <div class="stat-card">
            <h3>Total Balance</h3>
            <div class="stat-value">₹${totalBalance.toFixed(2)}</div>
        </div>
    `;
}

function populateAccountSelects(accounts) {
    const activeAccounts = accounts.filter(a => a.status === 'active');
    
    const fromAccountSelect = document.getElementById('fromAccount');
    const transactionAccountSelect = document.getElementById('transactionAccount');
    
    const options = activeAccounts.map(acc => 
        `<option value="${acc.account_id}">${acc.account_number} (${acc.account_type} - ${acc.currency} ${parseFloat(acc.balance).toFixed(2)})</option>`
    ).join('');
    
    if (fromAccountSelect) {
        fromAccountSelect.innerHTML = '<option value="">Select Account</option>' + options;
    }
    
    if (transactionAccountSelect) {
        transactionAccountSelect.innerHTML = '<option value="">Select an account</option>' + options;
    }
}

function loadActiveAccounts(selectId) {
    fetch('/api/user/accounts')
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                const activeAccounts = data.accounts.filter(a => a.status === 'active');
                const select = document.getElementById(selectId);
                select.innerHTML = '<option value="">Select Account</option>' + 
                    activeAccounts.map(acc => 
                        `<option value="${acc.account_id}">${acc.account_number} (${acc.account_type})</option>`
                    ).join('');
            }
        });
}

// Create Account Form
document.getElementById('createAccountForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        account_type: document.getElementById('accountType').value
    };
    
    try {
        const response = await fetch('/api/user/create-account', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        const alert = document.getElementById('createAccountAlert');
        
        if (data.success) {
            alert.className = 'alert alert-success';
            alert.textContent = data.message;
            alert.style.display = 'block';
            document.getElementById('createAccountForm').reset();
            setTimeout(() => {
                closeModal('createAccountModal');
                loadAccounts();
            }, 2000);
        } else {
            alert.className = 'alert alert-error';
            alert.textContent = data.message;
            alert.style.display = 'block';
        }
    } catch (error) {
        console.error('Error:', error);
    }
});

// Transfer Money Form
document.getElementById('transferForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        from_account: document.getElementById('fromAccount').value,
        to_account_number: document.getElementById('toAccountNumber').value,
        amount: document.getElementById('transferAmount').value,
        description: document.getElementById('transferDescription').value
    };
    
    try {
        const response = await fetch('/api/user/transfer', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        const alert = document.getElementById('transferAlert');
        
        if (data.success) {
            alert.className = 'alert alert-success';
            alert.textContent = data.message;
            alert.style.display = 'block';
            document.getElementById('transferForm').reset();
            loadAccounts();
        } else {
            alert.className = 'alert alert-error';
            alert.textContent = data.message;
            alert.style.display = 'block';
        }
    } catch (error) {
        console.error('Error:', error);
    }
});

// Apply Loan Form
document.getElementById('applyLoanForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        account_id: document.getElementById('loanAccount').value,
        loan_type: document.getElementById('loanType').value,
        loan_amount: document.getElementById('loanAmount').value,
        tenure_months: document.getElementById('tenureMonths').value,
        purpose: document.getElementById('loanPurpose').value
    };
    
    try {
        const response = await fetch('/api/user/apply-loan', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        const alert = document.getElementById('applyLoanAlert');
        
        if (data.success) {
            alert.className = 'alert alert-success';
            alert.textContent = data.message;
            alert.style.display = 'block';
            document.getElementById('applyLoanForm').reset();
            setTimeout(() => {
                closeModal('applyLoanModal');
                loadLoans();
            }, 2000);
        } else {
            alert.className = 'alert alert-error';
            alert.textContent = data.message;
            alert.style.display = 'block';
        }
    } catch (error) {
        console.error('Error:', error);
    }
});

// Deposit Form
document.getElementById('depositForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        account_id: document.getElementById('depositAccountId').value,
        amount: document.getElementById('depositAmount').value
    };
    
    try {
        const response = await fetch('/api/user/deposit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        const alert = document.getElementById('depositAlert');
        
        if (data.success) {
            alert.className = 'alert alert-success';
            alert.textContent = data.message;
            alert.style.display = 'block';
            document.getElementById('depositForm').reset();
            setTimeout(() => {
                closeModal('depositModal');
                loadAccounts();
            }, 1500);
        } else {
            alert.className = 'alert alert-error';
            alert.textContent = data.message;
            alert.style.display = 'block';
        }
    } catch (error) {
        console.error('Error:', error);
    }
});

// Load Loans
async function loadLoans() {
    try {
        const response = await fetch('/api/user/loans');
        const data = await response.json();
        
        if (data.success) {
            displayLoans(data.loans);
        }
    } catch (error) {
        console.error('Error loading loans:', error);
    }
}

function displayLoans(loans) {
    const container = document.getElementById('loansList');
    
    if (loans.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📄</div>
                <p>No loans found. Apply for a loan to get started!</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = `
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Loan ID</th>
                        <th>Type</th>
                        <th>Amount</th>
                        <th>Interest Rate</th>
                        <th>Tenure</th>
                        <th>Monthly EMI</th>
                        <th>Status</th>
                        <th>Applied Date</th>
                    </tr>
                </thead>
                <tbody>
                    ${loans.map(loan => `
                        <tr>
                            <td>#${loan.loan_id}</td>
                            <td style="text-transform: capitalize;">${loan.loan_type}</td>
                            <td>₹${parseFloat(loan.loan_amount).toFixed(2)}</td>
                            <td>${loan.interest_rate}%</td>
                            <td>${loan.tenure_months} months</td>
                            <td>₹${parseFloat(loan.monthly_emi).toFixed(2)}</td>
                            <td><span class="badge badge-${loan.status}">${loan.status}</span></td>
                            <td>${new Date(loan.applied_at).toLocaleDateString()}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Load Transactions
async function loadTransactions() {
    const accountId = document.getElementById('transactionAccount').value;
    
    if (!accountId) {
        document.getElementById('transactionsList').innerHTML = '';
        return;
    }
    
    try {
        const response = await fetch(`/api/user/transactions/${accountId}`);
        const data = await response.json();
        
        if (data.success) {
            displayTransactions(data.transactions);
        }
    } catch (error) {
        console.error('Error loading transactions:', error);
    }
}

function displayTransactions(transactions) {
    const container = document.getElementById('transactionsList');
    
    if (transactions.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📊</div>
                <p>No transactions found for this account.</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = `
        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Type</th>
                        <th>Amount</th>
                        <th>Fee</th>
                        <th>Description</th>
                        <th>Other Account</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    ${transactions.map(trans => `
                        <tr>
                            <td>${new Date(trans.transaction_date).toLocaleString()}</td>
                            <td><span class="badge ${trans.type === 'Credit' ? 'badge-active' : 'badge-pending'}">${trans.type}</span></td>
                            <td style="color: ${trans.type === 'Credit' ? 'green' : 'red'}; font-weight: 600;">
                                ${trans.type === 'Credit' ? '+' : '-'}₹${parseFloat(trans.amount).toFixed(2)}
                            </td>
                            <td>₹${parseFloat(trans.fee || 0).toFixed(2)}</td>
                            <td>${trans.description || '-'}</td>
                            <td>${trans.other_account || '-'}</td>
                            <td><span class="badge badge-active">${trans.status}</span></td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    loadAccounts();
    loadLoans();
});