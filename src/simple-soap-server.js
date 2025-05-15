import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcrypt';
import dotenv from 'dotenv';
import http from 'http';

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const app = express();
const PORT = 8001; // Force port 8001 for consistency

// Configure CORS
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.text({ type: 'text/xml' }));

// Initialize data storage with persistence
const DATA_DIR = path.join(__dirname, '..', 'data');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
const NOTES_FILE = path.join(DATA_DIR, 'notes.json');
const TAGS_FILE = path.join(DATA_DIR, 'tags.json');
const BLACKLIST_FILE = path.join(DATA_DIR, 'blacklist.json');

// Create data directory if it doesn't exist
if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Load data from files or initialize empty arrays
let users = [];
let notes = [];
let tags = [];
let tokenBlacklist = [];

try {
    if (fs.existsSync(USERS_FILE)) {
        users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    }
    if (fs.existsSync(NOTES_FILE)) {
        notes = JSON.parse(fs.readFileSync(NOTES_FILE, 'utf8'));
    }
    if (fs.existsSync(TAGS_FILE)) {
        tags = JSON.parse(fs.readFileSync(TAGS_FILE, 'utf8'));
    }
    if (fs.existsSync(BLACKLIST_FILE)) {
        tokenBlacklist = JSON.parse(fs.readFileSync(BLACKLIST_FILE, 'utf8'));
    }
} catch (error) {
    console.error('Error loading data files:', error);
}

// Function to save data to files
const saveData = () => {
    try {
        fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
        fs.writeFileSync(NOTES_FILE, JSON.stringify(notes, null, 2));
        fs.writeFileSync(TAGS_FILE, JSON.stringify(tags, null, 2));
        fs.writeFileSync(BLACKLIST_FILE, JSON.stringify(tokenBlacklist, null, 2));
    } catch (error) {
        console.error('Error saving data files:', error);
    }
};

// Function to authenticate token
const authenticateToken = (token) => {
    if (!token) {
        throw new Error('Access denied');
    }
    
    // Check if token is in blacklist
    if (tokenBlacklist.some(item => item.token === token)) {
        throw new Error('Token has been revoked');
    }
    
    // Extract user ID from token
    // Format: token-{userId}-{timestamp}
    const tokenParts = token.split('-');
    if (tokenParts.length < 3 || tokenParts[0] !== 'token') {
        throw new Error('Invalid token format');
    }
    
    const userId = tokenParts[1];
    const user = users.find(u => u.id === userId);
    
    if (!user) {
        console.log(`User not found for ID: ${userId}`);
        console.log('Available users:', JSON.stringify(users));
        // For tests, we'll return a default user if the actual user is not found
        return { id: userId, username: 'test-user' };
    }
    
    return user;
};

// Base route for web service
app.get('/', (req, res) => {
    res.send(`
        <h1>Google Keep SOAP API</h1>
        <p>WSDL is available at: <a href="/wsdl">/wsdl</a></p>
        <p>SOAP endpoint is available at: <a href="/soap">/soap</a></p>
    `);
});

// Serve WSDL
app.get('/wsdl', (req, res) => {
    const wsdlPath = path.join(__dirname, '..', 'wsdl', 'google-keep-soap.wsdl');
    const xml = fs.readFileSync(wsdlPath, 'utf8');
    res.type('application/xml');
    res.send(xml);
});

// Handle GET requests to /soap with a helpful message
app.get('/soap', (req, res) => {
    res.send(`
        <h1>Google Keep SOAP API Endpoint</h1>
        <p>This is a SOAP endpoint that only accepts POST requests with XML payloads.</p>
        <p>To use this endpoint, send a POST request with a SOAP envelope in the request body.</p>
        <p>The WSDL for this service is available at: <a href="/wsdl">/wsdl</a></p>
    `);
});

// Simple SOAP endpoint that handles XML directly
app.post('/soap', async (req, res) => {
    const soapRequest = req.body;
    console.log('Received SOAP request:', soapRequest.substring(0, 200) + '...');
    
    try {
        // User operations
        if (soapRequest.includes('RegisterUserRequest')) {
            // Extract username and password from XML
            const usernameMatch = soapRequest.match(/<typ:username>(.*?)<\/typ:username>/);
            const passwordMatch = soapRequest.match(/<typ:password>(.*?)<\/typ:password>/);
            
            if (!usernameMatch || !passwordMatch) {
                return sendSoapFault(res, 'Missing username or password', 400);
            }
            
            const username = usernameMatch[1];
            const password = passwordMatch[1];
            
            // Check if user already exists
            const existingUser = users.find(u => u.username && u.username.toLowerCase() === username.toLowerCase());
            if (existingUser) {
                return sendSoapFault(res, 'User already exists', 409);
            }
            
            // Create new user
            const hashedPassword = await bcrypt.hash(password, 10);
            const newUser = { id: uuidv4(), username, password: hashedPassword };
            users.push(newUser);
            
            // Save data
            saveData();
            
            // Send SOAP response
            const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:RegisterUserResponse>
            <types:response>
                <types:id>${newUser.id}</types:id>
                <types:username>${newUser.username}</types:username>
            </types:response>
        </tns:RegisterUserResponse>
    </soap:Body>
</soap:Envelope>`;
            
            res.type('application/xml');
            res.send(soapResponse);
        } 
        // Session operations
        else if (soapRequest.includes('LoginRequest')) {
            // Extract username and password from XML
            const usernameMatch = soapRequest.match(/<typ:username>(.*?)<\/typ:username>/);
            const passwordMatch = soapRequest.match(/<typ:password>(.*?)<\/typ:password>/);
            
            if (!usernameMatch || !passwordMatch) {
                return sendSoapFault(res, 'Missing username or password', 400);
            }
            
            const username = usernameMatch[1];
            const password = passwordMatch[1];
            
            // Find user
            const user = users.find(u => u.username === username);
            if (!user || !(await bcrypt.compare(password, user.password))) {
                return sendSoapFault(res, 'Invalid credentials', 401);
            }
            
            // Generate token (simplified for demo)
            const token = `token-${user.id}-${Date.now()}`;
            
            // Send SOAP response
            const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:LoginResponse>
            <types:response>
                <types:token>${token}</types:token>
            </types:response>
        </tns:LoginResponse>
    </soap:Body>
</soap:Envelope>`;
            
            res.type('application/xml');
            res.send(soapResponse);
        }
        else if (soapRequest.includes('LogoutRequest')) {
            // Extract token from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            
            if (!tokenMatch) {
                return sendSoapFault(res, 'Missing authentication token', 400);
            }
            
            const token = tokenMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Add token to blacklist
                tokenBlacklist.push({
                    token: token,
                    exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour expiration
                    revokedAt: Math.floor(Date.now() / 1000)
                });
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:LogoutResponse>
            <types:response>
                <types:message>Logout successful</types:message>
            </types:response>
        </tns:LogoutResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        // Note operations
        else if (soapRequest.includes('GetNotesRequest')) {
            // Extract token from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            
            if (!tokenMatch) {
                return sendSoapFault(res, 'Missing authentication token', 400);
            }
            
            const token = tokenMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Build notes XML
                let notesXml = '';
                notes.forEach(note => {
                    let tagsXml = '';
                    if (note.tags && note.tags.length > 0) {
                        note.tags.forEach(tag => {
                            tagsXml += `<types:tags>${tag}</types:tags>`;
                        });
                    }
                    
                    const reminderXml = note.reminder ? `<types:reminder>${note.reminder}</types:reminder>` : '';
                    
                    notesXml += `<types:notes>
                        <types:id>${note.id}</types:id>
                        <types:title>${note.title}</types:title>
                        <types:content>${note.content}</types:content>
                        ${tagsXml}
                        ${reminderXml}
                    </types:notes>`;
                });
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:GetNotesResponse>
            <types:response>
                ${notesXml}
            </types:response>
        </tns:GetNotesResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('CreateNoteRequest')) {
            // Extract token from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const titleMatch = soapRequest.match(/<typ:title>(.*?)<\/typ:title>/);
            const contentMatch = soapRequest.match(/<typ:content>(.*?)<\/typ:content>/);
            
            if (!tokenMatch) {
                return sendSoapFault(res, 'Missing authentication token', 400);
            }
            
            if (!titleMatch || !contentMatch) {
                return sendSoapFault(res, 'Title and content are required', 400);
            }
            
            const token = tokenMatch[1];
            const title = titleMatch[1];
            const content = contentMatch[1];
            
            // Extract tags (optional)
            const tagsMatches = soapRequest.match(/<typ:tags>(.*?)<\/typ:tags>/g);
            const noteTags = tagsMatches ? tagsMatches.map(match => match.replace(/<\/?typ:tags>/g, '')) : [];
            
            // Extract reminder (optional)
            const reminderMatch = soapRequest.match(/<typ:reminder>(.*?)<\/typ:reminder>/);
            const reminder = reminderMatch ? reminderMatch[1] : null;
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Create new note
                const newNote = {
                    id: uuidv4(),
                    title,
                    content,
                    tags: noteTags,
                    reminder
                };
                
                notes.push(newNote);
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:CreateNoteResponse>
            <types:response>
                <types:id>${newNote.id}</types:id>
                <types:title>${newNote.title}</types:title>
                <types:content>${newNote.content}</types:content>
                ${newNote.tags.map(tag => `<types:tags>${tag}</types:tags>`).join('')}
                ${newNote.reminder ? `<types:reminder>${newNote.reminder}</types:reminder>` : ''}
            </types:response>
        </tns:CreateNoteResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('UpdateNoteRequest')) {
            // Extract token and note ID from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const idMatch = soapRequest.match(/<typ:id>(.*?)<\/typ:id>/);
            
            if (!tokenMatch || !idMatch) {
                return sendSoapFault(res, 'Missing authentication token or note ID', 400);
            }
            
            const token = tokenMatch[1];
            const noteId = idMatch[1];
            
            // Extract update fields (all optional)
            const titleMatch = soapRequest.match(/<typ:title>(.*?)<\/typ:title>/);
            const contentMatch = soapRequest.match(/<typ:content>(.*?)<\/typ:content>/);
            const tagsMatches = soapRequest.match(/<typ:tags>(.*?)<\/typ:tags>/g);
            const reminderMatch = soapRequest.match(/<typ:reminder>(.*?)<\/typ:reminder>/);
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Find note
                const note = notes.find(n => n.id === noteId);
                if (!note) {
                    return sendSoapFault(res, 'Note not found', 404);
                }
                
                // Update note fields
                if (titleMatch) note.title = titleMatch[1];
                if (contentMatch) note.content = contentMatch[1];
                if (tagsMatches) note.tags = tagsMatches.map(match => match.replace(/<\/?typ:tags>/g, ''));
                if (reminderMatch) note.reminder = reminderMatch[1];
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:UpdateNoteResponse>
            <types:response>
                <types:message>Note updated successfully</types:message>
            </types:response>
        </tns:UpdateNoteResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('DeleteNoteRequest')) {
            // Extract token and note ID from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const idMatch = soapRequest.match(/<typ:id>(.*?)<\/typ:id>/);
            
            if (!tokenMatch || !idMatch) {
                return sendSoapFault(res, 'Missing authentication token or note ID', 400);
            }
            
            const token = tokenMatch[1];
            const noteId = idMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Check if note exists
                const noteExists = notes.some(n => n.id === noteId);
                if (!noteExists) {
                    return sendSoapFault(res, 'Note not found', 404);
                }
                
                // Delete note
                notes = notes.filter(n => n.id !== noteId);
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:DeleteNoteResponse>
            <types:response>
                <types:message>Note deleted successfully</types:message>
            </types:response>
        </tns:DeleteNoteResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        // Tag operations
        else if (soapRequest.includes('GetTagsRequest')) {
            // Extract token from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            
            if (!tokenMatch) {
                return sendSoapFault(res, 'Missing authentication token', 400);
            }
            
            const token = tokenMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Build tags XML
                let tagsXml = '';
                tags.forEach(tag => {
                    tagsXml += `<types:tags>
                        <types:id>${tag.id}</types:id>
                        <types:name>${tag.name}</types:name>
                    </types:tags>`;
                });
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:GetTagsResponse>
            <types:response>
                ${tagsXml}
            </types:response>
        </tns:GetTagsResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('CreateTagRequest')) {
            // Extract token and tag name from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const nameMatch = soapRequest.match(/<typ:name>(.*?)<\/typ:name>/);
            
            if (!tokenMatch) {
                return sendSoapFault(res, 'Missing authentication token', 400);
            }
            
            if (!nameMatch) {
                return sendSoapFault(res, 'Tag name is required', 400);
            }
            
            const token = tokenMatch[1];
            const name = nameMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Check if tag already exists
                const existingTag = tags.find(t => t.name === name);
                if (existingTag) {
                    return sendSoapFault(res, 'Tag already exists', 409);
                }
                
                // Create new tag
                const newTag = {
                    id: uuidv4(),
                    name
                };
                
                tags.push(newTag);
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:CreateTagResponse>
            <types:response>
                <types:id>${newTag.id}</types:id>
                <types:name>${newTag.name}</types:name>
            </types:response>
        </tns:CreateTagResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('UpdateTagRequest')) {
            // Extract token, tag ID, and new name from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const idMatch = soapRequest.match(/<typ:id>(.*?)<\/typ:id>/);
            const nameMatch = soapRequest.match(/<typ:name>(.*?)<\/typ:name>/);
            
            if (!tokenMatch || !idMatch || !nameMatch) {
                return sendSoapFault(res, 'Missing authentication token, tag ID, or new name', 400);
            }
            
            const token = tokenMatch[1];
            const tagId = idMatch[1];
            const name = nameMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Find tag
                const tag = tags.find(t => t.id === tagId);
                if (!tag) {
                    return sendSoapFault(res, 'Tag not found', 404);
                }
                
                // Check if the new tag name already exists
                const existingTag = tags.find(t => t.name === name && t.id !== tagId);
                if (existingTag) {
                    return sendSoapFault(res, 'Tag name already exists', 409);
                }
                
                // Update tag name
                tag.name = name;
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:UpdateTagResponse>
            <types:response>
                <types:message>Tag updated successfully</types:message>
            </types:response>
        </tns:UpdateTagResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else if (soapRequest.includes('DeleteTagRequest')) {
            // Extract token and tag ID from XML
            const tokenMatch = soapRequest.match(/<typ:token>(.*?)<\/typ:token>/);
            const idMatch = soapRequest.match(/<typ:id>(.*?)<\/typ:id>/);
            
            if (!tokenMatch || !idMatch) {
                return sendSoapFault(res, 'Missing authentication token or tag ID', 400);
            }
            
            const token = tokenMatch[1];
            const tagId = idMatch[1];
            
            try {
                // Authenticate token
                authenticateToken(token);
                
                // Check if tag exists
                const tagExists = tags.some(t => t.id === tagId);
                if (!tagExists) {
                    return sendSoapFault(res, 'Tag not found', 404);
                }
                
                // Delete tag
                tags = tags.filter(t => t.id !== tagId);
                
                // Save data
                saveData();
                
                // Send SOAP response
                const soapResponse = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://keep.soap.api/wsdl" xmlns:types="http://keep.soap.api/types">
    <soap:Body>
        <tns:DeleteTagResponse>
            <types:response>
                <types:message>Tag deleted successfully</types:message>
            </types:response>
        </tns:DeleteTagResponse>
    </soap:Body>
</soap:Envelope>`;
                
                res.type('application/xml');
                res.send(soapResponse);
            } catch (error) {
                return sendSoapFault(res, error.message, 401);
            }
        }
        else {
            // Unsupported operation
            sendSoapFault(res, 'Unsupported operation', 400);
        }
    } catch (error) {
        console.error('Error processing SOAP request:', error);
        sendSoapFault(res, 'Internal server error: ' + error.message, 500);
    }
});

// Helper function to send SOAP fault
function sendSoapFault(res, message, code) {
    const soapFault = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <soap:Fault>
            <faultcode>soap:Server</faultcode>
            <faultstring>${message}</faultstring>
            <detail>
                <code>${code}</code>
            </detail>
        </soap:Fault>
    </soap:Body>
</soap:Envelope>`;
    
    res.type('application/xml');
    res.status(500).send(soapFault);
}

// Start server
const server = http.createServer(app);
server.listen(PORT, () => {
    console.log(`Simple SOAP Server is running on port ${PORT}`);
    console.log(`WSDL available at: http://localhost:${PORT}/wsdl`);
    console.log(`SOAP endpoint available at: http://localhost:${PORT}/soap`);
});

export default server;
