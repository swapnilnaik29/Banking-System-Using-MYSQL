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
    
    // Load data for the selected tab
    if (tabName === 'all-accounts') {
        loadAllAccounts();
    } else if (tabName === 'all-loans') {
        loadAllLoans();
    }
}

// Logout function
async function logout() {
    const response = await fetch('/api/logout', { method: 'POST' });
    if (response.ok) {
        window.location.href = '/admin-login';
    }
}

// Load Statistics
async function loadStats() {
    try {
        const response = await fetch('/api/admin/stats');
        const data = await response.json();
        
        if (data.success) {
            displayStats(data.stats);
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

function displayStats(stats) {
    const container = document.getElementById('statsContainer');
    
    container.innerHTML = `
        <div class="stat-card">
            <h3>Total Users</h3>
            <div class="stat-value">${stats.users.total_users}</div>
        </div>
        <div class="stat-card">
            <h3>Active Users</h3>
            <div class="stat-value">${stats.users.active_users}</div>
        </div>
        <div class="stat-card">
            <h3>Total Accounts</h3>
            <div class="stat-value">${stats.accounts.total_accounts}</div>
        </div>
        <div class="stat-card">
            <h3>Pending Accounts</h3>
            <div class="stat-value">${stats.accounts.pending_accounts}</div>
        </div>
        <div class="stat-card">
            <h3>Total Balance</h3>
            <div class="stat-value">₹${parseFloat(stats.accounts.total_balance || 0).toFixed(2)}</div>
        </div>
        <div class="stat-card">
            <h3>Total Loans</h3>
            <div class="stat-value">${stats.loans.total_loans}</div>
        </div>
        <div class="stat-card">
            <h3>Pending Loans</h3>
            <div class="stat-value">${stats.loans.pending_loans}</div>
        </div>
        <div class="stat-card">
            <h3>Loan Amount</h3>
            <div class="stat-value">₹${parseFloat(stats.loans.total_loan_amount || 0).toFixed(2)}</div>
        </div>
    `;
}

// Load Pending Accounts
async function loadPendingAccounts() {
    try {
        const response = await fetch('/api/admin/pending-accounts');
        const data = await response.json();
        
        if (data.success) {
            displayPendingAccounts(data.accounts);
        }
    } catch (error) {
        console.error('Error loading pending accounts:', error);
    }
}

function displayPendingAccounts(accounts) {
    const container = document.getElementById('pendingAccountsList');
    
    if (accounts.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">✅</div>
                <p>No pending account approvals</p>
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
                        <th>Customer Name</th>
                        <th>Email</th>
                        <th>Phone</th>
                        <th>Account Type</th>
                        <th>Created Date</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    ${accounts.map(acc => `
                        <tr>
                            <td>${acc.account_number}</td>
                            <td>${acc.full_name}</td>
                            <td>${acc.email}</td>
                            <td>${acc.phone}</td>
                            <td style="text-transform: capitalize;">${acc.account_type}</td>
                            <td>${new Date(acc.created_at).toLocaleString()}</td>
                            <td>
                                <button class="btn btn-success" style="padding: 0.5rem 1rem; font-size: 0.875rem;" 
                                        onclick="approveAccount(${acc.account_id})">
                                    Approve
                                </button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Approve Account
async function approveAccount(accountId) {
    if (!confirm('Are you sure you want to approve this account?')) {
        return;
    }
    
    try {
        const response = await fetch('/api/admin/approve-account', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ account_id: accountId })
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert(data.message);
            loadPendingAccounts();
            loadStats();
        } else {
            alert('Error: ' + data.message);
        }
    } catch (error) {
        console.error('Error approving account:', error);
        alert('Failed to approve account');
    }
}

// Load Pending Loans
async function loadPendingLoans() {
    try {
        const response = await fetch('/api/admin/pending-loans');
        const data = await response.json();
        
        if (data.success) {
            displayPendingLoans(data.loans);
        }
    } catch (error) {
        console.error('Error loading pending loans:', error);
    }
}

function displayPendingLoans(loans) {
    const container = document.getElementById('pendingLoansList');
    
    if (loans.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">✅</div>
                <p>No pending loan applications</p>
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
                        <th>Customer Name</th>
                        <th>Email</th>
                        <th>Account Number</th>
                        <th>Loan Type</th>
                        <th>Amount</th>
                        <th>Interest Rate</th>
                        <th>Tenure</th>
                        <th>Monthly EMI</th>
                        <th>Purpose</th>
                        <th>Applied Date</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${loans.map(loan => `
                        <tr>
                            <td>#${loan.loan_id}</td>
                            <td>${loan.full_name}</td>
                            <td>${loan.email}</td>
                            <td>${loan.account_number}</td>
                            <td style="text-transform: capitalize;">${loan.loan_type}</td>
                            <td>₹${parseFloat(loan.loan_amount).toFixed(2)}</td>
                            <td>${loan.interest_rate}%</td>
                            <td>${loan.tenure_months} months</td>
                            <td>₹${parseFloat(loan.monthly_emi).toFixed(2)}</td>
                            <td>${loan.purpose}</td>
                            <td>${new Date(loan.applied_at).toLocaleString()}</td>
                            <td>
                                <button class="btn btn-success" style="padding: 0.5rem 1rem; font-size: 0.875rem; margin-right: 0.5rem;" 
                                        onclick="approveLoan(${loan.loan_id}, true)">
                                    Approve
                                </button>
                                <button class="btn btn-danger" style="padding: 0.5rem 1rem; font-size: 0.875rem;" 
                                        onclick="approveLoan(${loan.loan_id}, false)">
                                    Reject
                                </button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Approve/Reject Loan
async function approveLoan(loanId, approve) {
    const action = approve ? 'approve' : 'reject';
    if (!confirm(`Are you sure you want to ${action} this loan application?`)) {
        return;
    }
    
    try {
        const response = await fetch('/api/admin/approve-loan', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                loan_id: loanId,
                approve: approve
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert(data.message);
            loadPendingLoans();
            loadStats();
        } else {
            alert('Error: ' + data.message);
        }
    } catch (error) {
        console.error('Error processing loan:', error);
        alert('Failed to process loan application');
    }
}

// Load All Accounts
async function loadAllAccounts() {
    try {
        const response = await fetch('/api/admin/all-accounts');
        const data = await response.json();
        
        if (data.success) {
            displayAllAccounts(data.accounts);
        }
    } catch (error) {
        console.error('Error loading all accounts:', error);
    }
}

function displayAllAccounts(accounts) {
    const container = document.getElementById('allAccountsList');
    
    if (accounts.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📭</div>
                <p>No accounts found</p>
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
                        <th>Customer Name</th>
                        <th>Email</th>
                        <th>Phone</th>
                        <th>Type</th>
                        <th>Balance</th>
                        <th>Currency</th>
                        <th>Status</th>
                        <th>Transactions</th>
                        <th>Total Credits</th>
                        <th>Total Debits</th>
                    </tr>
                </thead>
                <tbody>
                    ${accounts.map(acc => `
                        <tr>
                            <td>${acc.account_number}</td>
                            <td>${acc.full_name}</td>
                            <td>${acc.email}</td>
                            <td>${acc.phone}</td>
                            <td style="text-transform: capitalize;">${acc.account_type}</td>
                            <td>₹${parseFloat(acc.balance).toFixed(2)}</td>
                            <td>${acc.currency}</td>
                            <td><span class="badge badge-${acc.status}">${acc.status}</span></td>
                            <td>${acc.transaction_count}</td>
                            <td style="color: green;">₹${parseFloat(acc.total_credits).toFixed(2)}</td>
                            <td style="color: red;">₹${parseFloat(acc.total_debits).toFixed(2)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Load All Loans
async function loadAllLoans() {
    try {
        const response = await fetch('/api/admin/all-loans');
        const data = await response.json();
        
        if (data.success) {
            displayAllLoans(data.loans);
        }
    } catch (error) {
        console.error('Error loading all loans:', error);
    }
}

function displayAllLoans(loans) {
    const container = document.getElementById('allLoansList');
    
    if (loans.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📄</div>
                <p>No loans found</p>
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
                        <th>Customer Name</th>
                        <th>Email</th>
                        <th>Account Number</th>
                        <th>Loan Type</th>
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
                            <td>${loan.full_name}</td>
                            <td>${loan.email}</td>
                            <td>${loan.account_number}</td>
                            <td style="text-transform: capitalize;">${loan.loan_type}</td>
                            <td>₹${parseFloat(loan.loan_amount).toFixed(2)}</td>
                            <td>${loan.interest_rate}%</td>
                            <td>${loan.tenure_months} months</td>
                            <td>₹${parseFloat(loan.monthly_emi).toFixed(2)}</td>
                            <td><span class="badge badge-${loan.status}">${loan.status}</span></td>
                            <td>${new Date(loan.applied_at).toLocaleString()}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadPendingAccounts();
    loadPendingLoans();
});