// Admin Panel JavaScript
// Base URL for API
const API_BASE = 'http://127.0.0.1:8000';
let authToken = localStorage.getItem('auth_token') || null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    if (authToken) {
        showDashboard();
        loadUserInfo();
    } else {
        showLogin();
    }

    // Login form
    document.getElementById('loginForm').addEventListener('submit', handleLogin);
    document.getElementById('logoutBtn').addEventListener('click', handleLogout);

    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    // Create buttons
    document.getElementById('createFlightBtn').addEventListener('click', () => showCreateFlightModal());
    document.getElementById('createAirportBtn').addEventListener('click', () => showCreateAirportModal());
    document.getElementById('createAirplaneBtn').addEventListener('click', () => showCreateAirplaneModal());
    document.getElementById('createAnnouncementBtn').addEventListener('click', () => showCreateAnnouncementModal());
    document.getElementById('createUserBtn').addEventListener('click', () => showCreateUserModal());
    document.getElementById('refreshBookingsBtn').addEventListener('click', () => loadBookings());
});

// API Helper
async function apiCall(endpoint, options = {}) {
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };

    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }

    try {
        const response = await fetch(`${API_BASE}${endpoint}`, {
            ...options,
            headers
        });

        if (response.status === 401) {
            // Only logout if we had a token (means session expired)
            if (authToken) {
                handleLogout();
            }
            const error = await response.json().catch(() => ({ detail: 'Unauthorized' }));
            throw new Error(error.detail || 'Unauthorized');
        }

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Request failed');
        }

        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}

// Auth
async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('loginError');

    try {
        // Login without auth token first
        const response = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email, password })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Login failed');
        }

        const loginData = await response.json();
        
        // Get token from response
        const token = loginData.access_token;
        
        if (!token) {
            throw new Error('No token received from server');
        }
        
        console.log('Token received, length:', token.length); // Debug
        
        // Set token before making authenticated request
        authToken = token;
        localStorage.setItem('auth_token', token);

        // Test token first with debug endpoint
        const debugResponse = await fetch(`${API_BASE}/debug/token`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        const debugData = await debugResponse.json();
        console.log('Debug token response:', debugData);
        
        if (debugData.status !== 'valid') {
            throw new Error('Token validation failed: ' + (debugData.error || 'Unknown error'));
        }
        
        // Now check user role - make direct call to ensure token is properly sent
        const userResponse = await fetch(`${API_BASE}/me`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('User response status:', userResponse.status); // Debug

        if (!userResponse.ok) {
            const errorText = await userResponse.text();
            let errorData;
            try {
                errorData = JSON.parse(errorText);
            } catch {
                errorData = { detail: errorText || 'Unauthorized' };
            }
            authToken = null;
            localStorage.removeItem('auth_token');
            throw new Error(errorData.detail || 'Failed to verify user. Please try again.');
        }

        const user = await userResponse.json();
        
        if (user.role !== 'STAFF') {
            authToken = null;
            localStorage.removeItem('auth_token');
            throw new Error('Access denied. Staff account required.');
        }

        showDashboard();
        loadUserInfo();
        errorDiv.textContent = '';
        errorDiv.classList.remove('show');
    } catch (error) {
        errorDiv.textContent = error.message;
        errorDiv.classList.add('show');
    }
}

function handleLogout() {
    authToken = null;
    localStorage.removeItem('auth_token');
    showLogin();
}

async function loadUserInfo() {
    try {
        const user = await apiCall('/me');
        document.getElementById('userEmail').textContent = user.email;
    } catch (error) {
        console.error('Failed to load user info:', error);
    }
}

// UI Navigation
function showLogin() {
    document.getElementById('loginSection').classList.remove('hidden');
    document.getElementById('dashboardSection').classList.add('hidden');
}

function showDashboard() {
    document.getElementById('loginSection').classList.add('hidden');
    document.getElementById('dashboardSection').classList.remove('hidden');
    switchTab('flights');
}

function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tabName}Tab`);
    });

    // Load data for active tab
    switch(tabName) {
        case 'flights':
            loadFlights();
            break;
        case 'airports':
            loadAirports();
            break;
        case 'airplanes':
            loadAirplanes();
            break;
        case 'announcements':
            loadAnnouncements();
            break;
        case 'users':
            loadUsers();
            break;
        case 'bookings':
            loadBookings();
            break;
    }
}

// Modal
function showModal(title, content) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = content;
    document.getElementById('modalOverlay').classList.remove('hidden');
}

function closeModal() {
    document.getElementById('modalOverlay').classList.add('hidden');
}

// Flights
async function loadFlights() {
    const listDiv = document.getElementById('flightsList');
    listDiv.innerHTML = '<div class="loading">Loading flights...</div>';

    try {
        const flights = await apiCall('/flights');
        
        if (flights.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No flights found. Create your first flight!</p></div>';
            return;
        }

        listDiv.innerHTML = flights.map(flight => `
            <div class="data-card">
                <div class="data-card-header">
                    <div class="data-card-title">${flight.flight_number}</div>
                    <span class="status-badge status-${flight.status.toLowerCase()}">${flight.status}</span>
                </div>
                <div class="data-card-body">
                    <p><strong>Route:</strong> ${flight.origin_airport.code} → ${flight.destination_airport.code}</p>
                    <p><strong>Departure:</strong> ${formatDateTime(flight.departure_time)}</p>
                    <p><strong>Arrival:</strong> ${formatDateTime(flight.arrival_time)}</p>
                    <p><strong>Base Price:</strong> $${flight.base_price.toFixed(2)}</p>
                </div>
                <div class="data-card-actions">
                    <button class="btn btn-secondary" onclick="updateFlightStatus(${flight.id}, '${flight.status}')">Update Status</button>
                    <button class="btn btn-danger" onclick="deleteFlight(${flight.id}, '${flight.flight_number}')">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

function showCreateFlightModal() {
    Promise.all([
        apiCall('/airports'),
        apiCall('/airplanes')
    ]).then(([airports, airplanes]) => {
        const content = `
            <form id="createFlightForm">
                <div class="form-group">
                    <label>Flight Number:</label>
                    <input type="text" name="flight_number" required placeholder="AA123">
                </div>
                <div class="form-group">
                    <label>Origin Airport:</label>
                    <select name="origin_airport_id" required>
                        <option value="">Select origin</option>
                        ${airports.map(a => `<option value="${a.id}">${a.code} - ${a.name}</option>`).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label>Destination Airport:</label>
                    <select name="destination_airport_id" required>
                        <option value="">Select destination</option>
                        ${airports.map(a => `<option value="${a.id}">${a.code} - ${a.name}</option>`).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label>Airplane:</label>
                    <select name="airplane_id" required>
                        <option value="">Select airplane</option>
                        ${airplanes.map(a => `<option value="${a.id}">${a.model} (${a.total_seats} seats)</option>`).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label>Departure Time:</label>
                    <input type="datetime-local" name="departure_time" required>
                </div>
                <div class="form-group">
                    <label>Arrival Time:</label>
                    <input type="datetime-local" name="arrival_time" required>
                </div>
                <div class="form-group">
                    <label>Base Price:</label>
                    <input type="number" name="base_price" step="0.01" required placeholder="299.99">
                </div>
                <div class="form-group">
                    <button type="submit" class="btn btn-primary">Create Flight</button>
                </div>
            </form>
        `;
        showModal('Create New Flight', content);
        
        document.getElementById('createFlightForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const data = {
                flight_number: formData.get('flight_number'),
                origin_airport_id: parseInt(formData.get('origin_airport_id')),
                destination_airport_id: parseInt(formData.get('destination_airport_id')),
                airplane_id: parseInt(formData.get('airplane_id')),
                departure_time: formData.get('departure_time').replace('T', ' ') + ':00',
                arrival_time: formData.get('arrival_time').replace('T', ' ') + ':00',
                base_price: parseFloat(formData.get('base_price')),
                status: 'SCHEDULED'
            };

            try {
                await apiCall('/flights', {
                    method: 'POST',
                    body: JSON.stringify(data)
                });
                closeModal();
                loadFlights();
                showSuccess('Flight created successfully!');
            } catch (error) {
                alert('Error: ' + error.message);
            }
        });
    });
}

async function updateFlightStatus(flightId, currentStatus) {
    const statuses = ['SCHEDULED', 'BOARDING', 'DEPARTED', 'ARRIVED', 'DELAYED', 'CANCELLED'];
    const content = `
        <form id="updateStatusForm">
            <div class="form-group">
                <label>New Status:</label>
                <select name="status" required>
                    ${statuses.map(s => `<option value="${s}" ${s === currentStatus ? 'selected' : ''}>${s}</option>`).join('')}
                </select>
            </div>
            <div class="form-group">
                <button type="submit" class="btn btn-primary">Update Status</button>
            </div>
        </form>
    `;
    showModal('Update Flight Status', content);
    
    document.getElementById('updateStatusForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(e.target);
        const newStatus = formData.get('status');
        try {
            // Send status as query parameter (FastAPI expects it as a parameter)
            await apiCall(`/flights/${flightId}/status?new_status=${newStatus}`, {
                method: 'PATCH'
            });
            closeModal();
            loadFlights();
            showSuccess('Status updated successfully!');
        } catch (error) {
            alert('Error: ' + error.message);
        }
    });
}

async function deleteFlight(flightId, flightNumber) {
    if (!confirm(`Are you sure you want to delete flight ${flightNumber}? This action cannot be undone.`)) {
        return;
    }

    try {
        await apiCall(`/flights/${flightId}`, {
            method: 'DELETE'
        });
        loadFlights();
        showSuccess('Flight deleted successfully!');
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

// Airports
async function loadAirports() {
    const listDiv = document.getElementById('airportsList');
    listDiv.innerHTML = '<div class="loading">Loading airports...</div>';

    try {
        const airports = await apiCall('/airports');
        
        if (airports.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No airports found. Create your first airport!</p></div>';
            return;
        }

        listDiv.innerHTML = airports.map(airport => `
            <div class="data-card">
                <div class="data-card-header">
                    <div class="data-card-title">${airport.code}</div>
                </div>
                <div class="data-card-body">
                    <p><strong>Name:</strong> ${airport.name}</p>
                    <p><strong>Location:</strong> ${airport.city}, ${airport.country}</p>
                </div>
                <div class="data-card-actions">
                    <button class="btn btn-danger" onclick="deleteAirport(${airport.id}, '${airport.code}')">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

function showCreateAirportModal() {
    const content = `
        <form id="createAirportForm">
            <div class="form-group">
                <label>Airport Code:</label>
                <input type="text" name="code" maxlength="3" required placeholder="JFK" style="text-transform: uppercase;">
            </div>
            <div class="form-group">
                <label>Airport Name:</label>
                <input type="text" name="name" required placeholder="John F. Kennedy International Airport">
            </div>
            <div class="form-group">
                <label>City:</label>
                <input type="text" name="city" required placeholder="New York">
            </div>
            <div class="form-group">
                <label>Country:</label>
                <input type="text" name="country" required placeholder="USA">
            </div>
            <div class="form-group">
                <button type="submit" class="btn btn-primary">Create Airport</button>
            </div>
        </form>
    `;
    showModal('Create New Airport', content);
    
    document.getElementById('createAirportForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            code: formData.get('code').toUpperCase(),
            name: formData.get('name'),
            city: formData.get('city'),
            country: formData.get('country')
        };

        try {
            await apiCall('/airports', {
                method: 'POST',
                body: JSON.stringify(data)
            });
            closeModal();
            loadAirports();
            showSuccess('Airport created successfully!');
        } catch (error) {
            alert('Error: ' + error.message);
        }
    });
}

async function deleteAirport(airportId, airportCode) {
    if (!confirm(`Are you sure you want to delete airport ${airportCode}? This action cannot be undone.`)) {
        return;
    }

    try {
        await apiCall(`/airports/${airportId}`, {
            method: 'DELETE'
        });
        loadAirports();
        showSuccess('Airport deleted successfully!');
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

// Airplanes
async function loadAirplanes() {
    const listDiv = document.getElementById('airplanesList');
    listDiv.innerHTML = '<div class="loading">Loading airplanes...</div>';

    try {
        const airplanes = await apiCall('/airplanes');
        
        if (airplanes.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No airplanes found. Create your first airplane!</p></div>';
            return;
        }

        listDiv.innerHTML = airplanes.map(airplane => `
            <div class="data-card">
                <div class="data-card-header">
                    <div class="data-card-title">${airplane.model}</div>
                </div>
                <div class="data-card-body">
                    <p><strong>Total Seats:</strong> ${airplane.total_seats}</p>
                    <p><strong>Configuration:</strong> ${airplane.rows} rows × ${airplane.seats_per_row} seats</p>
                </div>
                <div class="data-card-actions">
                    <button class="btn btn-danger" onclick="deleteAirplane(${airplane.id}, '${airplane.model}')">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

function showCreateAirplaneModal() {
    const content = `
        <form id="createAirplaneForm">
            <div class="form-group">
                <label>Model:</label>
                <input type="text" name="model" required placeholder="Boeing 737">
            </div>
            <div class="form-group">
                <label>Total Seats:</label>
                <input type="number" name="total_seats" required placeholder="150">
            </div>
            <div class="form-group">
                <label>Number of Rows:</label>
                <input type="number" name="rows" required placeholder="25">
            </div>
            <div class="form-group">
                <label>Seats per Row:</label>
                <input type="number" name="seats_per_row" required placeholder="6">
            </div>
            <div class="form-group">
                <button type="submit" class="btn btn-primary">Create Airplane</button>
            </div>
        </form>
    `;
    showModal('Create New Airplane', content);
    
    document.getElementById('createAirplaneForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            model: formData.get('model'),
            total_seats: parseInt(formData.get('total_seats')),
            rows: parseInt(formData.get('rows')),
            seats_per_row: parseInt(formData.get('seats_per_row'))
        };

        if (data.rows * data.seats_per_row !== data.total_seats) {
            alert('Rows × Seats per row must equal total seats');
            return;
        }

        try {
            await apiCall('/airplanes', {
                method: 'POST',
                body: JSON.stringify(data)
            });
            closeModal();
            loadAirplanes();
            showSuccess('Airplane created successfully!');
        } catch (error) {
            alert('Error: ' + error.message);
        }
    });
}

async function deleteAirplane(airplaneId, airplaneModel) {
    if (!confirm(`Are you sure you want to delete airplane ${airplaneModel}? This action cannot be undone.`)) {
        return;
    }

    try {
        await apiCall(`/airplanes/${airplaneId}`, {
            method: 'DELETE'
        });
        loadAirplanes();
        showSuccess('Airplane deleted successfully!');
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

// Announcements
async function loadAnnouncements() {
    const listDiv = document.getElementById('announcementsList');
    listDiv.innerHTML = '<div class="loading">Loading announcements...</div>';

    try {
        // Load announcements and flights in parallel (use staff endpoint to get all)
        const [announcements, flights] = await Promise.all([
            apiCall('/staff/announcements'),  // Get all announcements for admin
            apiCall('/flights')
        ]);
        
        // Create flight lookup map
        const flightMap = {};
        flights.forEach(f => flightMap[f.id] = f);
        
        if (announcements.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No announcements found. Create your first announcement!</p></div>';
            return;
        }

        listDiv.innerHTML = announcements.map(announcement => {
            const flight = announcement.flight_id ? flightMap[announcement.flight_id] : null;
            const targetText = flight 
                ? `<span class="status-badge status-boarding">Flight ${flight.flight_number}</span>` 
                : '<span class="status-badge status-scheduled">General</span>';
            
            return `
                <div class="data-card">
                    <div class="data-card-header">
                        <div class="data-card-title">${announcement.title}</div>
                        <div>
                            ${targetText}
                            ${announcement.is_active ? '<span class="status-badge status-arrived">Active</span>' : '<span class="status-badge status-cancelled">Inactive</span>'}
                        </div>
                    </div>
                    <div class="data-card-body">
                        <p>${announcement.message}</p>
                        ${flight ? `<p style="margin-top: 10px; color: #666; font-size: 14px;"><strong>Target:</strong> Passengers of ${flight.flight_number} (${flight.origin_airport.code} → ${flight.destination_airport.code})</p>` : ''}
                        <p style="margin-top: 10px; color: #999; font-size: 14px;">Created: ${formatDateTime(announcement.created_at)}</p>
                    </div>
                    <div class="data-card-actions">
                        <button class="btn btn-danger" onclick="deleteAnnouncement(${announcement.id}, '${announcement.title}')">Delete</button>
                    </div>
                </div>
            `;
        }).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

async function showCreateAnnouncementModal() {
    // Load flights for dropdown
    let flights = [];
    try {
        flights = await apiCall('/flights');
    } catch (error) {
        console.error('Failed to load flights:', error);
    }
    
    const flightOptions = flights.map(f => 
        `<option value="${f.id}">${f.flight_number} - ${f.origin_airport.code} → ${f.destination_airport.code} (${new Date(f.departure_time).toLocaleDateString()})</option>`
    ).join('');
    
    const content = `
        <form id="createAnnouncementForm">
            <div class="form-group">
                <label>Title:</label>
                <input type="text" name="title" required placeholder="Important Notice">
            </div>
            <div class="form-group">
                <label>Message:</label>
                <textarea name="message" rows="5" required placeholder="Enter announcement message..."></textarea>
            </div>
            <div class="form-group">
                <label>Target Audience:</label>
                <select name="flight_id">
                    <option value="">General (All Users)</option>
                    ${flightOptions}
                </select>
                <small style="color: #666;">Select a flight to target only passengers of that flight, or leave as "General" for all users.</small>
            </div>
            <div class="form-group">
                <button type="submit" class="btn btn-primary">Create Announcement</button>
            </div>
        </form>
    `;
    showModal('Create New Announcement', content);
    
    document.getElementById('createAnnouncementForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(e.target);
        const flightId = formData.get('flight_id');
        const data = {
            title: formData.get('title'),
            message: formData.get('message'),
            flight_id: flightId ? parseInt(flightId) : null
        };

        try {
            await apiCall('/announcements', {
                method: 'POST',
                body: JSON.stringify(data)
            });
            closeModal();
            loadAnnouncements();
            showSuccess('Announcement created successfully!');
        } catch (error) {
            alert('Error: ' + error.message);
        }
    });
}

async function deleteAnnouncement(announcementId, announcementTitle) {
    if (!confirm(`Are you sure you want to delete announcement "${announcementTitle}"? This action cannot be undone.`)) {
        return;
    }

    try {
        await apiCall(`/announcements/${announcementId}`, {
            method: 'DELETE'
        });
        loadAnnouncements();
        showSuccess('Announcement deleted successfully!');
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

// Users
async function loadUsers() {
    const listDiv = document.getElementById('usersList');
    listDiv.innerHTML = '<div class="loading">Loading users...</div>';

    try {
        const users = await apiCall('/staff/users');
        
        if (users.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No users found.</p></div>';
            return;
        }

        listDiv.innerHTML = users.map(user => `
            <div class="data-card">
                <div class="data-card-header">
                    <div class="data-card-title">${user.email}</div>
                    <span class="status-badge ${user.role === 'STAFF' ? 'status-arrived' : 'status-scheduled'}">${user.role}</span>
                </div>
                <div class="data-card-body">
                    <p><strong>User ID:</strong> ${user.id}</p>
                    <p><strong>Role:</strong> ${user.role}</p>
                    ${user.created_at ? `<p><strong>Created:</strong> ${formatDateTime(user.created_at)}</p>` : ''}
                    ${user.profile ? `
                        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #e0e0e0;">
                            <p style="font-weight: bold; margin-bottom: 8px;">Passenger Profile:</p>
                            <p><strong>Name:</strong> ${user.profile.first_name} ${user.profile.last_name}</p>
                            <p><strong>Phone:</strong> ${user.profile.phone}</p>
                            <p><strong>Passport:</strong> ${user.profile.passport_number}</p>
                            <p><strong>Nationality:</strong> ${user.profile.nationality}</p>
                            ${user.profile.date_of_birth ? `<p><strong>Date of Birth:</strong> ${new Date(user.profile.date_of_birth).toLocaleDateString()}</p>` : ''}
                        </div>
                    ` : user.role === 'PASSENGER' ? '<p style="color: #999; font-size: 14px; margin-top: 8px;"><em>No profile completed yet</em></p>' : ''}
                </div>
            </div>
        `).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

function showCreateUserModal() {
    const content = `
        <form id="createUserForm">
            <div class="form-group">
                <label>Email:</label>
                <input type="email" name="email" required placeholder="user@example.com">
            </div>
            <div class="form-group">
                <label>Password:</label>
                <input type="password" name="password" required placeholder="password123" minlength="6">
            </div>
            <div class="form-group">
                <label>Role:</label>
                <select name="role" required>
                    <option value="PASSENGER">Passenger</option>
                    <option value="STAFF">Staff</option>
                </select>
            </div>
            <div class="form-group">
                <button type="submit" class="btn btn-primary">Create User</button>
            </div>
        </form>
    `;
    showModal('Create New User', content);
    
    document.getElementById('createUserForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = {
            email: formData.get('email'),
            password: formData.get('password'),
            role: formData.get('role')
        };

        try {
            await apiCall('/staff/users', {
                method: 'POST',
                body: JSON.stringify(data)
            });
            closeModal();
            loadUsers();
            showSuccess('User created successfully!');
        } catch (error) {
            alert('Error: ' + error.message);
        }
    });
}

// Bookings
async function loadBookings() {
    const listDiv = document.getElementById('bookingsList');
    listDiv.innerHTML = '<div class="loading">Loading bookings...</div>';

    try {
        const bookings = await apiCall('/staff/bookings');
        
        if (bookings.length === 0) {
            listDiv.innerHTML = '<div class="data-card"><p>No bookings found.</p></div>';
            return;
        }

        listDiv.innerHTML = bookings.map(booking => `
            <div class="data-card">
                <div class="data-card-header">
                    <div class="data-card-title">${booking.booking_reference}</div>
                </div>
                <div class="data-card-body">
                    <p><strong>Flight:</strong> ${booking.flight.flight_number}</p>
                    <p><strong>Route:</strong> ${booking.flight.origin_airport.code} → ${booking.flight.destination_airport.code}</p>
                    <p><strong>Seat:</strong> ${booking.seat.row_number}${booking.seat.seat_letter}</p>
                    <p><strong>Total Price:</strong> $${booking.total_price.toFixed(2)}</p>
                    <p><strong>Created:</strong> ${formatDateTime(booking.created_at)}</p>
                </div>
            </div>
        `).join('');
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

// Helpers
function formatDateTime(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function showSuccess(message) {
    // You can implement a toast notification here
    alert(message);
}

