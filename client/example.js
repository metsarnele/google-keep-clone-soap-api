import { createClientAsync } from 'soap';
import readline from 'readline';
import util from 'util';

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Promisify readline question
const question = util.promisify(rl.question).bind(rl);

// SOAP client configuration
const wsdlUrl = 'http://localhost:8001/wsdl';
let soapClient = null;
let authToken = null;

// Helper function to create SOAP client
async function createSoapClient() {
  try {
    soapClient = await createClientAsync(wsdlUrl);
    console.log('SOAP client created successfully');
    return true;
  } catch (error) {
    console.error('Failed to create SOAP client:', error.message);
    return false;
  }
}

// Helper function to handle errors
function handleError(error) {
  if (error.root?.Envelope?.Body?.Fault?.fault) {
    const fault = error.root.Envelope.Body.Fault.fault;
    console.error(`Error: ${fault.message} (Code: ${fault.code})`);
  } else {
    console.error('Error:', error.message || error);
  }
}

// User operations
async function registerUser() {
  try {
    const username = await question('Enter username: ');
    const password = await question('Enter password: ');

    const result = await soapClient.RegisterUserAsync({
      user: { username, password }
    });

    const response = result[0].response;
    console.log('User registered successfully!');
    console.log('User ID:', response.id);
    console.log('Username:', response.username);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function updateUser() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const userId = await question('Enter user ID to update: ');
    const username = await question('Enter new username (leave empty to keep current): ');
    const password = await question('Enter new password (leave empty to keep current): ');

    const update = {};
    if (username) update.username = username;
    if (password) update.password = password;

    const result = await soapClient.UpdateUserAsync({
      auth: { token: authToken },
      id: { id: userId },
      update
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function deleteUser() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const userId = await question('Enter user ID to delete: ');

    const result = await soapClient.DeleteUserAsync({
      auth: { token: authToken },
      id: { id: userId }
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

// Session operations
async function login() {
  try {
    const username = await question('Enter username: ');
    const password = await question('Enter password: ');

    const result = await soapClient.LoginAsync({
      credentials: { username, password }
    });

    authToken = result[0].response.token;
    console.log('Login successful!');
    console.log('Auth Token:', authToken);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function logout() {
  if (!authToken) {
    console.log('You are not logged in!');
    return false;
  }

  try {
    const result = await soapClient.LogoutAsync({
      auth: { token: authToken }
    });

    console.log(result[0].response.message);
    authToken = null;
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

// Note operations
async function getNotes() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const result = await soapClient.GetNotesAsync({
      auth: { token: authToken }
    });

    const notes = result[0].response.notes;
    console.log('Notes:');
    if (notes && notes.length > 0) {
      notes.forEach(note => {
        console.log(`ID: ${note.id}`);
        console.log(`Title: ${note.title}`);
        console.log(`Content: ${note.content}`);
        console.log(`Tags: ${note.tags ? note.tags.join(', ') : 'None'}`);
        console.log(`Reminder: ${note.reminder || 'None'}`);
        console.log('-----------------------');
      });
    } else {
      console.log('No notes found.');
    }
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function createNote() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const title = await question('Enter note title: ');
    const content = await question('Enter note content: ');
    const tagsInput = await question('Enter tags (comma separated, leave empty for none): ');
    
    const tags = tagsInput ? tagsInput.split(',').map(tag => tag.trim()) : [];
    
    const result = await soapClient.CreateNoteAsync({
      auth: { token: authToken },
      note: { title, content, tags }
    });

    const note = result[0].response;
    console.log('Note created successfully!');
    console.log('Note ID:', note.id);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function updateNote() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const noteId = await question('Enter note ID to update: ');
    const title = await question('Enter new title (leave empty to keep current): ');
    const content = await question('Enter new content (leave empty to keep current): ');
    const tagsInput = await question('Enter new tags (comma separated, leave empty to keep current): ');
    
    const update = {};
    if (title) update.title = title;
    if (content) update.content = content;
    if (tagsInput) update.tags = tagsInput.split(',').map(tag => tag.trim());
    
    const result = await soapClient.UpdateNoteAsync({
      auth: { token: authToken },
      id: { id: noteId },
      update
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function deleteNote() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const noteId = await question('Enter note ID to delete: ');

    const result = await soapClient.DeleteNoteAsync({
      auth: { token: authToken },
      id: { id: noteId }
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

// Tag operations
async function getTags() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const result = await soapClient.GetTagsAsync({
      auth: { token: authToken }
    });

    const tags = result[0].response.tags;
    console.log('Tags:');
    if (tags && tags.length > 0) {
      tags.forEach(tag => {
        console.log(`ID: ${tag.id}`);
        console.log(`Name: ${tag.name}`);
        console.log('-----------------------');
      });
    } else {
      console.log('No tags found.');
    }
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function createTag() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const name = await question('Enter tag name: ');
    
    const result = await soapClient.CreateTagAsync({
      auth: { token: authToken },
      tag: { name }
    });

    const tag = result[0].response;
    console.log('Tag created successfully!');
    console.log('Tag ID:', tag.id);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function updateTag() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const tagId = await question('Enter tag ID to update: ');
    const name = await question('Enter new tag name: ');
    
    const result = await soapClient.UpdateTagAsync({
      auth: { token: authToken },
      id: { id: tagId },
      update: { name }
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

async function deleteTag() {
  if (!authToken) {
    console.log('You need to login first!');
    return false;
  }

  try {
    const tagId = await question('Enter tag ID to delete: ');

    const result = await soapClient.DeleteTagAsync({
      auth: { token: authToken },
      id: { id: tagId }
    });

    console.log(result[0].response.message);
    return true;
  } catch (error) {
    handleError(error);
    return false;
  }
}

// Main menu
async function showMenu() {
  console.log('\n===== Google Keep SOAP Client =====');
  console.log('1. Register User');
  console.log('2. Login');
  console.log('3. Logout');
  console.log('4. Update User');
  console.log('5. Delete User');
  console.log('6. Get Notes');
  console.log('7. Create Note');
  console.log('8. Update Note');
  console.log('9. Delete Note');
  console.log('10. Get Tags');
  console.log('11. Create Tag');
  console.log('12. Update Tag');
  console.log('13. Delete Tag');
  console.log('0. Exit');
  console.log('==================================');
  
  const choice = await question('Enter your choice: ');
  
  switch (choice) {
    case '1':
      await registerUser();
      break;
    case '2':
      await login();
      break;
    case '3':
      await logout();
      break;
    case '4':
      await updateUser();
      break;
    case '5':
      await deleteUser();
      break;
    case '6':
      await getNotes();
      break;
    case '7':
      await createNote();
      break;
    case '8':
      await updateNote();
      break;
    case '9':
      await deleteNote();
      break;
    case '10':
      await getTags();
      break;
    case '11':
      await createTag();
      break;
    case '12':
      await updateTag();
      break;
    case '13':
      await deleteTag();
      break;
    case '0':
      console.log('Exiting...');
      rl.close();
      process.exit(0);
      break;
    default:
      console.log('Invalid choice. Please try again.');
  }
  
  // Show menu again
  await showMenu();
}

// Main function
async function main() {
  console.log('Connecting to SOAP service...');
  const connected = await createSoapClient();
  
  if (connected) {
    await showMenu();
  } else {
    console.log('Failed to connect to SOAP service. Make sure the server is running.');
    rl.close();
    process.exit(1);
  }
}

// Start the client
main().catch(error => {
  console.error('Unhandled error:', error);
  rl.close();
  process.exit(1);
});
