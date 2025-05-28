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
const PORT = process.env.REST_PORT || 3000;

// Configure CORS
app.use(cors());
app.use(bodyParser.json());

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
    console.error('Error loading data:', error);
}

// Function to save data to files
const saveData = () => {
    try {
        fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
        fs.writeFileSync(NOTES_FILE, JSON.stringify(notes, null, 2));
        fs.writeFileSync(TAGS_FILE, JSON.stringify(tags, null, 2));
        fs.writeFileSync(BLACKLIST_FILE, JSON.stringify(tokenBlacklist, null, 2));
    } catch (error) {
        console.error('Error saving data:', error);
    }
};

// Middleware to authenticate token
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Access denied' });
    }
    
    // Check if token is in blacklist
    if (tokenBlacklist.some(item => item.token === token)) {
        return res.status(401).json({ error: 'Token has been revoked' });
    }
    
    // Extract user ID from token
    // Format: token-{userId}-{timestamp}
    const tokenParts = token.split('-');
    if (tokenParts.length < 3 || tokenParts[0] !== 'token') {
        return res.status(401).json({ error: 'Invalid token format' });
    }
    
    const userId = tokenParts[1];
    const user = users.find(u => u.id === userId);
    
    if (!user) {
        console.log(`User not found for ID: ${userId}`);
        console.log('Available users:', JSON.stringify(users));
        return res.status(401).json({ error: 'User not found' });
    }
    
    req.user = user;
    next();
};

// Base route
app.get('/', (req, res) => {
    res.json({
        message: 'Google Keep REST API',
        endpoints: [
            { method: 'POST', path: '/users', description: 'Register a new user' },
            { method: 'PUT', path: '/users/:id', description: 'Update a user' },
            { method: 'DELETE', path: '/users/:id', description: 'Delete a user' },
            { method: 'POST', path: '/login', description: 'Login' },
            { method: 'POST', path: '/logout', description: 'Logout' },
            { method: 'GET', path: '/notes', description: 'Get all notes' },
            { method: 'POST', path: '/notes', description: 'Create a note' },
            { method: 'PUT', path: '/notes/:id', description: 'Update a note' },
            { method: 'DELETE', path: '/notes/:id', description: 'Delete a note' },
            { method: 'GET', path: '/tags', description: 'Get all tags' },
            { method: 'POST', path: '/tags', description: 'Create a tag' },
            { method: 'PUT', path: '/tags/:id', description: 'Update a tag' },
            { method: 'DELETE', path: '/tags/:id', description: 'Delete a tag' }
        ]
    });
});

// User routes
app.post('/users', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required' });
        }
        
        if (users.some(user => user.username === username)) {
            return res.status(400).json({ error: 'Username already exists' });
        }
        
        const hashedPassword = await bcrypt.hash(password, 10);
        const newUser = {
            id: uuidv4(),
            username,
            password: hashedPassword
        };
        
        users.push(newUser);
        saveData();
        
        res.status(201).json({ id: newUser.id, username: newUser.username });
    } catch (error) {
        console.error('Error registering user:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.put('/users/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { username, password } = req.body;
        
        if (req.user.id !== id) {
            return res.status(403).json({ error: 'You can only update your own user' });
        }
        
        const userIndex = users.findIndex(user => user.id === id);
        if (userIndex === -1) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        if (username && username !== users[userIndex].username) {
            if (users.some(user => user.username === username)) {
                return res.status(400).json({ error: 'Username already exists' });
            }
            users[userIndex].username = username;
        }
        
        if (password) {
            users[userIndex].password = await bcrypt.hash(password, 10);
        }
        
        saveData();
        
        res.json({ message: 'User updated successfully' });
    } catch (error) {
        console.error('Error updating user:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.delete('/users/:id', authenticateToken, (req, res) => {
    try {
        const { id } = req.params;
        
        if (req.user.id !== id) {
            return res.status(403).json({ error: 'You can only delete your own user' });
        }
        
        const userIndex = users.findIndex(user => user.id === id);
        if (userIndex === -1) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        users.splice(userIndex, 1);
        
        // Remove user's notes
        notes = notes.filter(note => note.userId !== id);
        
        // Remove user's tags
        tags = tags.filter(tag => tag.userId !== id);
        
        saveData();
        
        res.json({ message: 'User deleted successfully' });
    } catch (error) {
        console.error('Error deleting user:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Authentication routes
app.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password are required' });
        }
        
        const user = users.find(user => user.username === username);
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const validPassword = await bcrypt.compare(password, user.password);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = `token-${user.id}-${Date.now()}`;
        
        res.json({ token });
    } catch (error) {
        console.error('Error logging in:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/logout', authenticateToken, (req, res) => {
    try {
        const authHeader = req.headers['authorization'];
        const token = authHeader && authHeader.split(' ')[1];
        
        tokenBlacklist.push({ token, timestamp: Date.now() });
        saveData();
        
        res.json({ message: 'Logged out successfully' });
    } catch (error) {
        console.error('Error logging out:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Note routes
app.get('/notes', authenticateToken, (req, res) => {
    try {
        const userNotes = notes.filter(note => note.userId === req.user.id);
        res.json(userNotes);
    } catch (error) {
        console.error('Error getting notes:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/notes', authenticateToken, (req, res) => {
    try {
        const { title, content, tags: noteTags } = req.body;
        
        if (!title || !content) {
            return res.status(400).json({ error: 'Title and content are required' });
        }
        
        const newNote = {
            id: uuidv4(),
            userId: req.user.id,
            title,
            content,
            tags: noteTags || [],
            createdAt: new Date().toISOString()
        };
        
        notes.push(newNote);
        saveData();
        
        res.status(201).json(newNote);
    } catch (error) {
        console.error('Error creating note:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.put('/notes/:id', authenticateToken, (req, res) => {
    try {
        const { id } = req.params;
        const { title, content, tags: noteTags } = req.body;
        
        const noteIndex = notes.findIndex(note => note.id === id && note.userId === req.user.id);
        if (noteIndex === -1) {
            return res.status(404).json({ error: 'Note not found' });
        }
        
        if (title) {
            notes[noteIndex].title = title;
        }
        
        if (content) {
            notes[noteIndex].content = content;
        }
        
        if (noteTags) {
            notes[noteIndex].tags = noteTags;
        }
        
        notes[noteIndex].updatedAt = new Date().toISOString();
        
        saveData();
        
        res.json({ message: 'Note updated successfully' });
    } catch (error) {
        console.error('Error updating note:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.delete('/notes/:id', authenticateToken, (req, res) => {
    try {
        const { id } = req.params;
        
        const noteIndex = notes.findIndex(note => note.id === id && note.userId === req.user.id);
        if (noteIndex === -1) {
            return res.status(404).json({ error: 'Note not found' });
        }
        
        notes.splice(noteIndex, 1);
        saveData();
        
        res.json({ message: 'Note deleted successfully' });
    } catch (error) {
        console.error('Error deleting note:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Tag routes
app.get('/tags', authenticateToken, (req, res) => {
    try {
        const userTags = tags.filter(tag => tag.userId === req.user.id);
        res.json(userTags);
    } catch (error) {
        console.error('Error getting tags:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/tags', authenticateToken, (req, res) => {
    try {
        const { name } = req.body;
        
        if (!name) {
            return res.status(400).json({ error: 'Tag name is required' });
        }
        
        if (tags.some(tag => tag.userId === req.user.id && tag.name === name)) {
            return res.status(400).json({ error: 'Tag already exists' });
        }
        
        const newTag = {
            id: uuidv4(),
            userId: req.user.id,
            name
        };
        
        tags.push(newTag);
        saveData();
        
        res.status(201).json(newTag);
    } catch (error) {
        console.error('Error creating tag:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.put('/tags/:id', authenticateToken, (req, res) => {
    try {
        const { id } = req.params;
        const { name } = req.body;
        
        if (!name) {
            return res.status(400).json({ error: 'Tag name is required' });
        }
        
        const tagIndex = tags.findIndex(tag => tag.id === id && tag.userId === req.user.id);
        if (tagIndex === -1) {
            return res.status(404).json({ error: 'Tag not found' });
        }
        
        if (tags.some(tag => tag.userId === req.user.id && tag.name === name && tag.id !== id)) {
            return res.status(400).json({ error: 'Tag name already exists' });
        }
        
        tags[tagIndex].name = name;
        saveData();
        
        res.json({ message: 'Tag updated successfully' });
    } catch (error) {
        console.error('Error updating tag:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.delete('/tags/:id', authenticateToken, (req, res) => {
    try {
        const { id } = req.params;
        
        const tagIndex = tags.findIndex(tag => tag.id === id && tag.userId === req.user.id);
        if (tagIndex === -1) {
            return res.status(404).json({ error: 'Tag not found' });
        }
        
        tags.splice(tagIndex, 1);
        saveData();
        
        res.json({ message: 'Tag deleted successfully' });
    } catch (error) {
        console.error('Error deleting tag:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Start server
const server = http.createServer(app);
server.listen(PORT, () => {
    console.log(`REST Server is running on port ${PORT}`);
});

export default server;
