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
    
    // Password visibility toggle
    const togglePasswordBtn = document.getElementById('togglePassword');
    const passwordInput = document.getElementById('password');
    const togglePasswordIcon = document.getElementById('togglePasswordIcon');
    
    if (togglePasswordBtn && passwordInput) {
        togglePasswordBtn.addEventListener('click', () => {
            const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
            passwordInput.setAttribute('type', type);
            togglePasswordIcon.textContent = type === 'password' ? '👁️' : '🙈';
        });
    }

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
    const searchPNRBtn = document.getElementById('searchPNRBtn');
    const searchPNR = document.getElementById('searchPNR');
    if (searchPNRBtn) {
        searchPNRBtn.addEventListener('click', () => searchBookingByPNR());
    }
    if (searchPNR) {
        searchPNR.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                searchBookingByPNR();
            }
        });
    }
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
                    <button class="btn btn-secondary" onclick="updateFlightSchedule(${flight.id})">Update Schedule</button>
                    <button class="btn btn-secondary" onclick="updateFlightGate(${flight.id})">Update Gate</button>
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

async function updateFlightSchedule(flightId) {
    try {
        const flight = await apiCall(`/flights/${flightId}`);
        const content = `
            <form id="updateScheduleForm">
                <div class="form-group">
                    <label>Departure Time:</label>
                    <input type="datetime-local" name="departure_time" value="${new Date(flight.departure_time).toISOString().slice(0, 16)}" required>
                </div>
                <div class="form-group">
                    <label>Arrival Time:</label>
                    <input type="datetime-local" name="arrival_time" value="${new Date(flight.arrival_time).toISOString().slice(0, 16)}" required>
                </div>
                <div class="form-group">
                    <button type="submit" class="btn btn-primary">Update Schedule</button>
                </div>
            </form>
        `;
        showModal('Update Flight Schedule', content);
        
        document.getElementById('updateScheduleForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const departureTime = new Date(formData.get('departure_time')).toISOString();
            const arrivalTime = new Date(formData.get('arrival_time')).toISOString();
            
            try {
                await apiCall(`/flights/${flightId}/schedule?departure_time=${departureTime}&arrival_time=${arrivalTime}`, {
                    method: 'PATCH'
                });
                closeModal();
                loadFlights();
                showSuccess('Schedule updated successfully!');
            } catch (error) {
                alert('Error: ' + error.message);
            }
        });
    } catch (error) {
        alert('Error loading flight: ' + error.message);
    }
}

async function updateFlightGate(flightId) {
    try {
        const flight = await apiCall(`/flights/${flightId}`);
        const content = `
            <form id="updateGateForm">
                <div class="form-group">
                    <label>Gate:</label>
                    <input type="text" name="gate" value="${flight.gate || ''}" placeholder="A12">
                </div>
                <div class="form-group">
                    <label>Terminal:</label>
                    <input type="text" name="terminal" value="${flight.terminal || ''}" placeholder="Terminal 1">
                </div>
                <div class="form-group">
                    <button type="submit" class="btn btn-primary">Update Gate/Terminal</button>
                </div>
            </form>
        `;
        showModal('Update Flight Gate/Terminal', content);
        
        document.getElementById('updateGateForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const gate = formData.get('gate');
            const terminal = formData.get('terminal');
            
            try {
                const params = new URLSearchParams();
                if (gate) params.append('gate', gate);
                if (terminal) params.append('terminal', terminal);
                
                await apiCall(`/flights/${flightId}/gate?${params.toString()}`, {
                    method: 'PATCH'
                });
                closeModal();
                loadFlights();
                showSuccess('Gate/Terminal updated successfully!');
            } catch (error) {
                alert('Error: ' + error.message);
            }
        });
    } catch (error) {
        alert('Error loading flight: ' + error.message);
    }
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
                    <button class="btn btn-secondary" onclick="viewAirplaneSeatMap(${airplane.id}, '${airplane.model}', ${airplane.rows}, ${airplane.seats_per_row})">View Seat Map</button>
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
                <button type="button" class="btn btn-secondary" onclick="previewSeatMap()" style="margin-right: 10px; margin-bottom: 10px;">Preview Seat Map</button>
                <button type="submit" class="btn btn-primary">Create Airplane</button>
            </div>
        </form>
        <div id="seatMapPreview" style="display: none; margin-top: 20px; padding: 15px; background: #f9f9f9; border-radius: 5px; max-height: 400px; overflow-y: auto;">
            <h4>Seat Map Preview</h4>
            <div id="previewContent"></div>
        </div>
    `;
    showModal('Create New Airplane', content);
    
    // Store seat configuration
    window.seatConfig = {};
    
    // Preview seat map function with interactive seat configuration
    window.previewSeatMap = function() {
        const formData = new FormData(document.getElementById('createAirplaneForm'));
        const rows = parseInt(formData.get('rows')) || 0;
        const seatsPerRow = parseInt(formData.get('seats_per_row')) || 0;
        
        if (rows === 0 || seatsPerRow === 0) {
            alert('Please enter rows and seats per row first');
            return;
        }
        
        const previewDiv = document.getElementById('seatMapPreview');
        const previewContent = document.getElementById('previewContent');
        previewDiv.style.display = 'block';
        
        // Initialize seat config if not exists
        if (!window.seatConfig || Object.keys(window.seatConfig).length === 0) {
            window.seatConfig = {};
            for (let row = 1; row <= rows; row++) {
                for (let seat = 0; seat < seatsPerRow; seat++) {
                    const seatLetter = String.fromCharCode(65 + seat);
                    const seatKey = `${row}${seatLetter}`;
                    window.seatConfig[seatKey] = {
                        seat_class: row <= 3 ? 'BUSINESS' : 'ECONOMY',
                        seat_category: 'STANDARD',
                        price_multiplier: row <= 3 ? 2.0 : 1.0
                    };
                }
            }
        }
        
        // Generate seat map preview with clickable seats
        let preview = '<div style="text-align: center; margin-bottom: 10px;"><strong>Front of Aircraft</strong></div>';
        preview += '<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 5px;">';
        preview += '<span style="width: 30px;"></span>';
        for (let i = 0; i < seatsPerRow; i++) {
            preview += `<span style="width: 30px; text-align: center; font-weight: bold;">${String.fromCharCode(65 + i)}</span>`;
        }
        preview += '</div>';
        
        for (let row = 1; row <= rows; row++) {
            preview += `<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 2px;">`;
            preview += `<span style="width: 30px; text-align: right; margin-right: 5px; font-weight: bold;">${row}</span>`;
            for (let seat = 0; seat < seatsPerRow; seat++) {
                const seatLetter = String.fromCharCode(65 + seat);
                const seatKey = `${row}${seatLetter}`;
                const config = window.seatConfig[seatKey] || { seat_class: 'ECONOMY', seat_category: 'STANDARD', price_multiplier: 1.0 };
                
                const isBusiness = config.seat_class === 'BUSINESS';
                const isExtraLegroom = config.seat_category === 'EXTRA_LEGROOM';
                
                let bgColor, borderColor;
                if (isBusiness) {
                    bgColor = '#ffa726';
                    borderColor = '#f57c00';
                } else if (isExtraLegroom) {
                    bgColor = '#ba68c8';
                    borderColor = '#9c27b0';
                } else {
                    bgColor = '#e8f5e9';
                    borderColor = '#ccc';
                }
                
                preview += `<span onclick="configureSeat(${row}, '${seatLetter}', ${rows}, ${seatsPerRow})" style="width: 30px; height: 30px; border: 1px solid ${borderColor}; display: inline-block; text-align: center; line-height: 30px; background: ${bgColor}; font-weight: ${isBusiness ? 'bold' : 'normal'}; cursor: pointer;" title="Click to configure: ${config.seat_class} - ${config.seat_category}">${seatLetter}</span>`;
            }
            preview += '</div>';
        }
        preview += '<div style="margin-top: 15px; padding: 10px; background: #f5f5f5; border-radius: 5px;">';
        preview += '<strong>Legend:</strong><br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ffa726; border: 1px solid #f57c00; margin-right: 5px;"></span> Business Class<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #e8f5e9; border: 1px solid #ccc; margin-right: 5px;"></span> Economy Standard<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ba68c8; border: 1px solid #9c27b0; margin-right: 5px;"></span> Extra Legroom<br>';
        preview += '<p style="margin-top: 10px; font-size: 12px; color: #666;">Click on any seat to configure its class and category</p>';
        preview += '</div>';
        
        previewContent.innerHTML = preview;
    };
    
    // Configure individual seat
    window.configureSeat = function(row, seatLetter, totalRows, seatsPerRow) {
        const seatKey = `${row}${seatLetter}`;
        const config = window.seatConfig[seatKey] || { seat_class: 'ECONOMY', seat_category: 'STANDARD', price_multiplier: 1.0 };
        
        // Save the current airplane creation modal content and form values
        const currentModalTitle = document.getElementById('modalTitle').textContent;
        const currentModalBody = document.getElementById('modalBody').innerHTML;
        const form = document.getElementById('createAirplaneForm');
        const formValues = form ? {
            model: form.querySelector('[name="model"]')?.value || '',
            total_seats: form.querySelector('[name="total_seats"]')?.value || '',
            rows: form.querySelector('[name="rows"]')?.value || '',
            seats_per_row: form.querySelector('[name="seats_per_row"]')?.value || ''
        } : {};
        window.savedAirplaneModal = {
            title: currentModalTitle,
            content: currentModalBody,
            formValues: formValues
        };
        
        const content = `
            <form id="configureSeatForm">
                <div class="form-group">
                    <label>Seat:</label>
                    <input type="text" value="${row}${seatLetter}" disabled>
                </div>
                <div class="form-group">
                    <label>Seat Class:</label>
                    <select name="seat_class" required>
                        <option value="ECONOMY" ${config.seat_class === 'ECONOMY' ? 'selected' : ''}>Economy</option>
                        <option value="BUSINESS" ${config.seat_class === 'BUSINESS' ? 'selected' : ''}>Business</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Seat Category:</label>
                    <select name="seat_category" required>
                        <option value="STANDARD" ${config.seat_category === 'STANDARD' ? 'selected' : ''}>Standard</option>
                        <option value="EXTRA_LEGROOM" ${config.seat_category === 'EXTRA_LEGROOM' ? 'selected' : ''}>Extra Legroom</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Price Multiplier:</label>
                    <input type="number" name="price_multiplier" step="0.1" value="${config.price_multiplier}" required>
                    <small style="color: #666;">1.0 = base price, 2.0 = double price, etc.</small>
                </div>
                <div class="form-group">
                    <button type="button" class="btn btn-secondary" onclick="applyToRowAndRestore(${row}, ${seatsPerRow})" style="margin-right: 10px; margin-bottom: 10px;">Apply to Entire Row</button>
                    <button type="submit" class="btn btn-primary">Save</button>
                </div>
            </form>
        `;
        
        showModal(`Configure Seat ${row}${seatLetter}`, content);
        
        document.getElementById('configureSeatForm').addEventListener('submit', (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            window.seatConfig[seatKey] = {
                seat_class: formData.get('seat_class'),
                seat_category: formData.get('seat_category'),
                price_multiplier: parseFloat(formData.get('price_multiplier'))
            };
            // Restore the airplane creation modal
            restoreAirplaneModal();
            previewSeatMap(); // Refresh preview
        });
    };
    
    // Function to restore the airplane creation modal
    window.restoreAirplaneModal = function() {
        if (window.savedAirplaneModal) {
            document.getElementById('modalTitle').textContent = window.savedAirplaneModal.title;
            document.getElementById('modalBody').innerHTML = window.savedAirplaneModal.content;
            
            // Restore form values if they were saved
            if (window.savedAirplaneModal.formValues) {
                const form = document.getElementById('createAirplaneForm');
                if (form) {
                    if (window.savedAirplaneModal.formValues.model) {
                        form.querySelector('[name="model"]').value = window.savedAirplaneModal.formValues.model;
                    }
                    if (window.savedAirplaneModal.formValues.total_seats) {
                        form.querySelector('[name="total_seats"]').value = window.savedAirplaneModal.formValues.total_seats;
                    }
                    if (window.savedAirplaneModal.formValues.rows) {
                        form.querySelector('[name="rows"]').value = window.savedAirplaneModal.formValues.rows;
                    }
                    if (window.savedAirplaneModal.formValues.seats_per_row) {
                        form.querySelector('[name="seats_per_row"]').value = window.savedAirplaneModal.formValues.seats_per_row;
                    }
                }
            }
            
            // Re-attach form submit handler (since we replaced the HTML, the handler is gone)
            const form = document.getElementById('createAirplaneForm');
            if (form) {
                form.addEventListener('submit', async (e) => {
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
                    
                    // Include seat configuration if available
                    if (window.seatConfig && Object.keys(window.seatConfig).length > 0) {
                        data.seat_config = window.seatConfig;
                    }

                    try {
                        await apiCall('/airplanes', {
                            method: 'POST',
                            body: JSON.stringify(data)
                        });
                        // Clear seat config after successful creation
                        window.seatConfig = {};
                        closeModal();
                        loadAirplanes();
                        showSuccess('Airplane created successfully!');
                    } catch (error) {
                        alert('Error: ' + error.message);
                    }
                });
            }
        }
        // Clear saved modal
        window.savedAirplaneModal = null;
    };
    
    // Apply configuration to entire row and restore modal
    window.applyToRowAndRestore = function(row, seatsPerRow) {
        const formData = new FormData(document.getElementById('configureSeatForm'));
        const seat_class = formData.get('seat_class');
        const seat_category = formData.get('seat_category');
        const price_multiplier = parseFloat(formData.get('price_multiplier'));
        
        for (let seat = 0; seat < seatsPerRow; seat++) {
            const seatLetter = String.fromCharCode(65 + seat);
            const seatKey = `${row}${seatLetter}`;
            window.seatConfig[seatKey] = {
                seat_class: seat_class,
                seat_category: seat_category,
                price_multiplier: price_multiplier
            };
        }
        
        // Restore the airplane creation modal
        restoreAirplaneModal();
        previewSeatMap(); // Refresh preview
        alert(`Configuration applied to entire row ${row}`);
    };
    
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
            const typeColor = getAnnouncementTypeColor(announcement.announcement_type || 'GENERAL');
            
            return `
                <div class="data-card">
                    <div class="data-card-header">
                        <div class="data-card-title">${announcement.title}</div>
                        <div>
                            <span class="status-badge" style="background: ${typeColor}">${announcement.announcement_type || 'GENERAL'}</span>
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
                <label>Announcement Type:</label>
                <select name="announcement_type" required>
                    <option value="GENERAL">General Information</option>
                    <option value="DELAY">Delay</option>
                    <option value="CANCELLATION">Cancellation</option>
                    <option value="GATE_CHANGE">Gate Change</option>
                    <option value="BOARDING">Boarding Started</option>
                </select>
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
            announcement_type: formData.get('announcement_type'),
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

        // Group bookings by flight
        const bookingsByFlight = {};
        bookings.forEach(booking => {
            const flightId = booking.flight_id;
            if (!bookingsByFlight[flightId]) {
                bookingsByFlight[flightId] = [];
            }
            bookingsByFlight[flightId].push(booking);
        });

        listDiv.innerHTML = Object.entries(bookingsByFlight).map(([flightId, flightBookings]) => {
            const flight = flightBookings[0].flight;
            return `
                <div class="data-card" style="margin-bottom: 20px;">
                    <div class="data-card-header">
                        <div class="data-card-title">${flight.flight_number} - ${flight.origin_airport.code} → ${flight.destination_airport.code}</div>
                        <button class="btn btn-secondary" onclick="viewFlightBookings(${flightId})">View All (${flightBookings.length})</button>
                    </div>
                    <div class="data-card-body">
                        <p><strong>Departure:</strong> ${formatDateTime(flight.departure_time)}</p>
                        <p><strong>Status:</strong> ${flight.status}</p>
                        <p><strong>Bookings:</strong> ${flightBookings.length}</p>
                    </div>
                </div>
            `;
        }).join('') + `
            <div class="data-card">
                <h3>All Bookings</h3>
                ${bookings.map(booking => `
                    <div style="border-bottom: 1px solid #eee; padding: 12px 0;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <strong>PNR:</strong> ${booking.booking_reference} | 
                                <strong>Flight:</strong> ${booking.flight.flight_number} | 
                                <strong>Seat:</strong> ${booking.seat.row_number}${booking.seat.seat_letter} | 
                                <strong>Status:</strong> ${booking.status}
                            </div>
                            <div>
                                ${booking.flight.status !== 'DEPARTED' ? `
                                    <button class="btn btn-danger" onclick="cancelBookingStaff(${booking.id}, '${booking.booking_reference}')" style="margin-right: 8px;">Cancel</button>
                                    <button class="btn btn-secondary" onclick="reassignSeat(${booking.id}, ${booking.flight_id})">Reassign Seat</button>
                                ` : ''}
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    } catch (error) {
        listDiv.innerHTML = `<div class="error-message show">Error: ${error.message}</div>`;
    }
}

async function viewFlightBookings(flightId) {
    try {
        const bookings = await apiCall(`/staff/bookings/flight/${flightId}`);
        const content = `
            <div style="max-height: 500px; overflow-y: auto;">
                <h3>Bookings for Flight ${bookings[0]?.flight?.flight_number || ''}</h3>
                ${bookings.map(booking => `
                    <div style="border-bottom: 1px solid #eee; padding: 12px 0;">
                        <p><strong>PNR:</strong> ${booking.booking_reference}</p>
                        <p><strong>Seat:</strong> ${booking.seat.row_number}${booking.seat.seat_letter}</p>
                        <p><strong>Status:</strong> ${booking.status}</p>
                        <p><strong>Price:</strong> $${booking.total_price.toFixed(2)}</p>
                        ${booking.flight.status !== 'DEPARTED' ? `
                            <button class="btn btn-danger" onclick="cancelBookingStaff(${booking.id}, '${booking.booking_reference}')">Cancel</button>
                            <button class="btn btn-secondary" onclick="reassignSeat(${booking.id}, ${booking.flight_id})">Reassign Seat</button>
                        ` : ''}
                    </div>
                `).join('')}
            </div>
        `;
        showModal('Flight Bookings', content);
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function searchBookingByPNR() {
    const pnr = document.getElementById('searchPNR').value.trim().toUpperCase();
    if (!pnr) {
        alert('Please enter a PNR');
        return;
    }
    
    try {
        const booking = await apiCall(`/staff/bookings/search?pnr=${pnr}`);
        const content = `
            <div>
                <h3>Booking Details</h3>
                <p><strong>PNR:</strong> ${booking.booking_reference}</p>
                <p><strong>Flight:</strong> ${booking.flight.flight_number}</p>
                <p><strong>Route:</strong> ${booking.flight.origin_airport.code} → ${booking.flight.destination_airport.code}</p>
                <p><strong>Seat:</strong> ${booking.seat.row_number}${booking.seat.seat_letter}</p>
                <p><strong>Status:</strong> ${booking.status}</p>
                <p><strong>Price:</strong> $${booking.total_price.toFixed(2)}</p>
                ${booking.flight.status !== 'DEPARTED' ? `
                    <button class="btn btn-danger" onclick="cancelBookingStaff(${booking.id}, '${booking.booking_reference}')">Cancel Booking</button>
                    <button class="btn btn-secondary" onclick="reassignSeat(${booking.id}, ${booking.flight_id})">Reassign Seat</button>
                ` : ''}
            </div>
        `;
        showModal('Booking Search Result', content);
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function cancelBookingStaff(bookingId, pnr) {
    if (!confirm(`Are you sure you want to cancel booking ${pnr}?`)) {
        return;
    }
    
    try {
        await apiCall(`/staff/bookings/${bookingId}`, {
            method: 'DELETE'
        });
        loadBookings();
        closeModal();
        showSuccess('Booking cancelled successfully!');
    } catch (error) {
        alert('Error: ' + error.message);
    }
}

async function reassignSeat(bookingId, flightId) {
    try {
        // Load available seats for this flight
        const seats = await apiCall(`/flights/${flightId}/seats`);
        const availableSeats = seats.filter(s => s.status === 'AVAILABLE' || s.status === 'HELD');
        
        const content = `
            <form id="reassignSeatForm">
                <div class="form-group">
                    <label>Select New Seat:</label>
                    <select name="new_seat_id" required>
                        ${availableSeats.map(seat => 
                            `<option value="${seat.id}">Row ${seat.row_number}${seat.seat_letter} - ${seat.seat_class} ($${seat.price.toFixed(2)})</option>`
                        ).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <button type="submit" class="btn btn-primary">Reassign Seat</button>
                </div>
            </form>
        `;
        showModal('Reassign Seat', content);
        
        document.getElementById('reassignSeatForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const newSeatId = parseInt(formData.get('new_seat_id'));
            
            try {
                await apiCall(`/staff/bookings/${bookingId}/reassign-seat?new_seat_id=${newSeatId}`, {
                    method: 'PATCH'
                });
                closeModal();
                loadBookings();
                showSuccess('Seat reassigned successfully!');
            } catch (error) {
                alert('Error: ' + error.message);
            }
        });
    } catch (error) {
        alert('Error: ' + error.message);
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

// View seat map for an airplane (template)
async function viewAirplaneSeatMap(airplaneId, model, rows, seatsPerRow) {
    let preview = '<div style="text-align: center; margin-bottom: 10px;"><strong>Front of Aircraft</strong></div>';
    preview += '<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 5px;">';
    preview += '<span style="width: 30px;"></span>'; // Spacer for row numbers
    for (let i = 0; i < seatsPerRow; i++) {
        preview += `<span style="width: 30px; text-align: center; font-weight: bold;">${String.fromCharCode(65 + i)}</span>`;
    }
    preview += '</div>';
    
    for (let row = 1; row <= rows; row++) {
        preview += `<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 2px;">`;
        preview += `<span style="width: 30px; text-align: right; margin-right: 5px; font-weight: bold;">${row}</span>`;
        for (let seat = 0; seat < seatsPerRow; seat++) {
            const seatLetter = String.fromCharCode(65 + seat);
            // First 3 rows are business class (amber/gold color)
            const isBusiness = row <= 3;
            const bgColor = isBusiness ? '#ffa726' : '#e8f5e9';
            const borderColor = isBusiness ? '#f57c00' : '#ccc';
            preview += `<span style="width: 30px; height: 30px; border: 1px solid ${borderColor}; display: inline-block; text-align: center; line-height: 30px; background: ${bgColor}; font-weight: ${isBusiness ? 'bold' : 'normal'};">${seatLetter}</span>`;
        }
        preview += '</div>';
    }
    preview += '<div style="margin-top: 15px; padding: 10px; background: #f5f5f5; border-radius: 5px;">';
    preview += '<strong>Legend:</strong><br>';
    preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ffa726; border: 1px solid #f57c00; margin-right: 5px;"></span> Business Class (Rows 1-3)<br>';
    preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #e8f5e9; border: 1px solid #ccc; margin-right: 5px;"></span> Economy Class';
    preview += '</div>';
    
    showModal(`Seat Map - ${model}`, `<div style="max-height: 500px; overflow-y: auto;">${preview}</div>`);
}

// View seat map for a flight (with actual seat statuses)
async function viewFlightSeatMap(flightId, flightNumber) {
    try {
        const seats = await apiCall(`/flights/${flightId}/seats`);
        
        if (seats.length === 0) {
            showModal(`Seat Map - ${flightNumber}`, '<p>No seats found for this flight.</p>');
            return;
        }
        
        // Group seats by row
        const seatsByRow = {};
        let maxSeatsPerRow = 0;
        seats.forEach(seat => {
            if (!seatsByRow[seat.row_number]) {
                seatsByRow[seat.row_number] = [];
            }
            seatsByRow[seat.row_number].push(seat);
            maxSeatsPerRow = Math.max(maxSeatsPerRow, seatsByRow[seat.row_number].length);
        });
        
        const rows = Object.keys(seatsByRow).map(Number).sort((a, b) => a - b);
        
        let preview = '<div style="text-align: center; margin-bottom: 10px;"><strong>Front of Aircraft</strong></div>';
        preview += '<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 5px;">';
        preview += '<span style="width: 30px;"></span>'; // Spacer for row numbers
        for (let i = 0; i < maxSeatsPerRow; i++) {
            preview += `<span style="width: 30px; text-align: center; font-weight: bold;">${String.fromCharCode(65 + i)}</span>`;
        }
        preview += '</div>';
        
        rows.forEach(rowNum => {
            preview += `<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 2px;">`;
            preview += `<span style="width: 30px; text-align: right; margin-right: 5px; font-weight: bold;">${rowNum}</span>`;
            
            const rowSeats = seatsByRow[rowNum].sort((a, b) => a.seat_letter.localeCompare(b.seat_letter));
            const seatMap = {};
            rowSeats.forEach(seat => {
                seatMap[seat.seat_letter] = seat;
            });
            
            for (let i = 0; i < maxSeatsPerRow; i++) {
                const seatLetter = String.fromCharCode(65 + i);
                const seat = seatMap[seatLetter];
                
                if (seat) {
                    const isBusiness = seat.seat_class === 'BUSINESS';
                    const isExtraLegroom = seat.seat_category === 'EXTRA_LEGROOM';
                    let bgColor, borderColor, textColor = 'black';
                    
                    if (seat.status === 'BOOKED') {
                        bgColor = '#ef5350';
                        borderColor = '#c62828';
                        textColor = 'white';
                    } else if (seat.status === 'HELD') {
                        bgColor = '#ff6f00';
                        borderColor = '#e65100';
                    } else if (isBusiness) {
                        bgColor = '#ffa726';
                        borderColor = '#f57c00';
                    } else if (isExtraLegroom) {
                        bgColor = '#ba68c8';
                        borderColor = '#9c27b0';
                    } else {
                        bgColor = '#e8f5e9';
                        borderColor = '#ccc';
                    }
                    
                    preview += `<span style="width: 30px; height: 30px; border: 1px solid ${borderColor}; display: inline-block; text-align: center; line-height: 30px; background: ${bgColor}; color: ${textColor}; font-weight: ${isBusiness ? 'bold' : 'normal'};" title="Row ${seat.row_number}${seat.seat_letter} - ${seat.seat_class} - ${seat.seat_category} - ${seat.status}">${seat.seat_letter}</span>`;
                } else {
                    preview += `<span style="width: 30px; height: 30px; display: inline-block;"></span>`;
                }
            }
            preview += '</div>';
        });
        
        preview += '<div style="margin-top: 15px; padding: 10px; background: #f5f5f5; border-radius: 5px;">';
        preview += '<strong>Legend:</strong><br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ffa726; border: 1px solid #f57c00; margin-right: 5px;"></span> Business Class (Available)<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #e8f5e9; border: 1px solid #ccc; margin-right: 5px;"></span> Economy Standard (Available)<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ba68c8; border: 1px solid #9c27b0; margin-right: 5px;"></span> Extra Legroom (Available)<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ff6f00; border: 1px solid #e65100; margin-right: 5px;"></span> Held<br>';
        preview += '<span style="display: inline-block; width: 20px; height: 20px; background: #ef5350; border: 1px solid #c62828; margin-right: 5px;"></span> Booked';
        preview += '</div>';
        preview += '<div style="margin-top: 15px;">';
        preview += '<button class="btn btn-primary" onclick="manageFlightSeats(' + flightId + ', \'' + flightNumber + '\')">Manage Seats</button>';
        preview += '</div>';
        
        showModal(`Seat Map - ${flightNumber}`, `<div style="max-height: 500px; overflow-y: auto;">${preview}</div>`);
    } catch (error) {
        alert('Error loading seat map: ' + error.message);
    }
}

function getAnnouncementTypeColor(type) {
    switch(type) {
        case 'DELAY':
            return '#ff9800';
        case 'CANCELLATION':
            return '#f44336';
        case 'GATE_CHANGE':
            return '#2196f3';
        case 'BOARDING':
            return '#4caf50';
        default:
            return '#9e9e9e';
    }
}

// Manage seats for a flight
async function manageFlightSeats(flightId, flightNumber) {
    try {
        const seats = await apiCall(`/flights/${flightId}/seats`);
        
        if (seats.length === 0) {
            alert('No seats found for this flight.');
            return;
        }
        
        // Group seats by row
        const seatsByRow = {};
        let maxSeatsPerRow = 0;
        seats.forEach(seat => {
            if (!seatsByRow[seat.row_number]) {
                seatsByRow[seat.row_number] = [];
            }
            seatsByRow[seat.row_number].push(seat);
            maxSeatsPerRow = Math.max(maxSeatsPerRow, seatsByRow[seat.row_number].length);
        });
        
        const rows = Object.keys(seatsByRow).map(Number).sort((a, b) => a - b);
        
        let content = '<div style="max-height: 400px; overflow-y: auto; margin-bottom: 20px;">';
        content += '<div style="text-align: center; margin-bottom: 10px;"><strong>Front of Aircraft</strong></div>';
        content += '<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 5px;">';
        content += '<span style="width: 30px;"></span>';
        for (let i = 0; i < maxSeatsPerRow; i++) {
            content += `<span style="width: 30px; text-align: center; font-weight: bold;">${String.fromCharCode(65 + i)}</span>`;
        }
        content += '</div>';
        
        rows.forEach(rowNum => {
            content += `<div style="display: flex; justify-content: center; gap: 2px; margin-bottom: 2px;">`;
            content += `<span style="width: 30px; text-align: right; margin-right: 5px; font-weight: bold;">${rowNum}</span>`;
            
            const rowSeats = seatsByRow[rowNum].sort((a, b) => a.seat_letter.localeCompare(b.seat_letter));
            const seatMap = {};
            rowSeats.forEach(seat => {
                seatMap[seat.seat_letter] = seat;
            });
            
            for (let i = 0; i < maxSeatsPerRow; i++) {
                const seatLetter = String.fromCharCode(65 + i);
                const seat = seatMap[seatLetter];
                
                if (seat) {
                    const isBusiness = seat.seat_class === 'BUSINESS';
                    const isExtraLegroom = seat.seat_category === 'EXTRA_LEGROOM';
                    let bgColor, borderColor, textColor = 'black';
                    
                    if (seat.status === 'BOOKED') {
                        bgColor = '#ef5350';
                        borderColor = '#c62828';
                        textColor = 'white';
                    } else if (seat.status === 'HELD') {
                        bgColor = '#ff6f00';
                        borderColor = '#e65100';
                    } else if (isBusiness) {
                        bgColor = '#ffa726';
                        borderColor = '#f57c00';
                    } else if (isExtraLegroom) {
                        bgColor = '#ba68c8';
                        borderColor = '#9c27b0';
                    } else {
                        bgColor = '#e8f5e9';
                        borderColor = '#ccc';
                    }
                    
                    content += `<span onclick="editSeat(${seat.id}, ${flightId}, '${seat.seat_letter}', ${seat.row_number})" style="width: 30px; height: 30px; border: 1px solid ${borderColor}; display: inline-block; text-align: center; line-height: 30px; background: ${bgColor}; color: ${textColor}; font-weight: ${isBusiness ? 'bold' : 'normal'}; cursor: pointer;" title="Click to edit: ${seat.seat_class} - ${seat.seat_category}">${seat.seat_letter}</span>`;
                } else {
                    content += `<span style="width: 30px; height: 30px; display: inline-block;"></span>`;
                }
            }
            content += '</div>';
        });
        
        content += '</div>';
        content += '<div style="padding: 10px; background: #f5f5f5; border-radius: 5px; margin-top: 15px;">';
        content += '<strong>Legend:</strong><br>';
        content += '<span style="display: inline-block; width: 20px; height: 20px; background: #ffa726; border: 1px solid #f57c00; margin-right: 5px;"></span> Business<br>';
        content += '<span style="display: inline-block; width: 20px; height: 20px; background: #e8f5e9; border: 1px solid #ccc; margin-right: 5px;"></span> Economy<br>';
        content += '<span style="display: inline-block; width: 20px; height: 20px; background: #ba68c8; border: 1px solid #9c27b0; margin-right: 5px;"></span> Extra Legroom<br>';
        content += '<span style="display: inline-block; width: 20px; height: 20px; background: #ff6f00; border: 1px solid #e65100; margin-right: 5px;"></span> Held<br>';
        content += '<span style="display: inline-block; width: 20px; height: 20px; background: #ef5350; border: 1px solid #c62828; margin-right: 5px;"></span> Booked<br>';
        content += '<p style="margin-top: 10px; font-size: 12px; color: #666;">Click on any seat to edit its properties</p>';
        content += '</div>';
        
        showModal(`Manage Seats - ${flightNumber}`, content);
    } catch (error) {
        alert('Error loading seats: ' + error.message);
    }
}

// Edit individual seat
async function editSeat(seatId, flightId, seatLetter, rowNumber) {
    try {
        const seats = await apiCall(`/flights/${flightId}/seats`);
        const seat = seats.find(s => s.id === seatId);
        
        if (!seat) {
            alert('Seat not found');
            return;
        }
        
        const content = `
            <form id="editSeatForm">
                <div class="form-group">
                    <label>Seat:</label>
                    <input type="text" value="${rowNumber}${seatLetter}" disabled>
                </div>
                <div class="form-group">
                    <label>Seat Class:</label>
                    <select name="seat_class" required>
                        <option value="ECONOMY" ${seat.seat_class === 'ECONOMY' ? 'selected' : ''}>Economy</option>
                        <option value="BUSINESS" ${seat.seat_class === 'BUSINESS' ? 'selected' : ''}>Business</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Seat Category:</label>
                    <select name="seat_category" required>
                        <option value="STANDARD" ${seat.seat_category === 'STANDARD' ? 'selected' : ''}>Standard</option>
                        <option value="EXTRA_LEGROOM" ${seat.seat_category === 'EXTRA_LEGROOM' ? 'selected' : ''}>Extra Legroom</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Price Multiplier:</label>
                    <input type="number" name="price_multiplier" step="0.1" value="${seat.price_multiplier}" required>
                    <small style="color: #666;">1.0 = base price, 2.0 = double price, etc.</small>
                </div>
                <div class="form-group">
                    <button type="submit" class="btn btn-primary">Update Seat</button>
                </div>
            </form>
        `;
        
        showModal(`Edit Seat ${rowNumber}${seatLetter}`, content);
        
        document.getElementById('editSeatForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            
            try {
                await apiCall(`/staff/flights/${flightId}/seats/${seatId}`, {
                    method: 'PATCH',
                    body: JSON.stringify({
                        seat_class: formData.get('seat_class'),
                        seat_category: formData.get('seat_category'),
                        price_multiplier: parseFloat(formData.get('price_multiplier'))
                    })
                });
                closeModal();
                manageFlightSeats(flightId, ''); // Refresh seat map
                showSuccess('Seat updated successfully!');
            } catch (error) {
                alert('Error updating seat: ' + error.message);
            }
        });
    } catch (error) {
        alert('Error loading seat: ' + error.message);
    }
}

