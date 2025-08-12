import { useState, useEffect } from 'react';
import { AuthClient } from '@dfinity/auth-client';
import { Actor } from '@dfinity/agent';
import { HttpAgent } from '@dfinity/agent';
import UploadForm from './components/UploadForm';
import './App.css';

// Declare global window properties
declare global {
  interface Window {
    actor: any;
    idlFactory: any;
  }
}

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState<any>(null);
  const [principal, setPrincipal] = useState<string>('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const initAuth = async () => {
      try {
        const client = await AuthClient.create();
        setAuthClient(client);
        
        const isAuthenticated = await client.isAuthenticated();
        setIsAuthenticated(isAuthenticated);
        
        if (isAuthenticated) {
          const identity = client.getIdentity();
          const principal = identity.getPrincipal();
          setPrincipal(principal.toText());
          
          // Initialize actor
          const agent = new HttpAgent({ identity });
          
          // Only fetch root key in development
          if (process.env.NODE_ENV !== 'production') {
            await agent.fetchRootKey();
          }
          
          const actor = Actor.createActor(
            (window as any).idlFactory,
            { agent, canisterId: process.env.CANISTER_ID_NFT_CANISTER! }
          );
          (window as any).actor = actor;
        }
      } catch (error) {
        console.error('Authentication initialization failed:', error);
      } finally {
        setIsLoading(false);
      }
    };
    
    initAuth();
  }, []);

  const login = async () => {
    if (!authClient) return;
    
    try {
      await authClient.login({
        identityProvider: process.env.REACT_APP_II_URL || 'http://localhost:8000/?canisterId=rdmx6-jaaaa-aaaaa-aaadq-cai',
        onSuccess: async () => {
          // Get identity and principal
          const identity = authClient.getIdentity();
          const principal = identity.getPrincipal();
          setPrincipal(principal.toText());
          setIsAuthenticated(true);
          
          // Initialize actor
          const agent = new HttpAgent({ identity });
          
          // Only fetch root key in development
          if (process.env.NODE_ENV !== 'production') {
            await agent.fetchRootKey();
          }
          
          const actor = Actor.createActor(
            (window as any).idlFactory,
            { agent, canisterId: process.env.CANISTER_ID_NFT_CANISTER! }
          );
          (window as any).actor = actor;
        },
        onError: (error) => {
          console.error('Login failed:', error);
          alert('Login failed. Please try again.');
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      alert('An error occurred during login.');
    }
  };

  const logout = async () => {
    if (!authClient) return;
    
    try {
      await authClient.logout();
      setIsAuthenticated(false);
      setPrincipal('');
      (window as any).actor = null;
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  if (isLoading) {
    return (
      <div className="App">
        <header>
          <h1>Chainverse Objects</h1>
        </header>
        <main>
          <p>Loading...</p>
        </main>
      </div>
    );
  }

  return (
    <div className="App">
      <header>
        <h1>Chainverse Objects</h1>
        {isAuthenticated ? (
          <div>
            <span>Welcome: {principal.slice(0, 8)}...{principal.slice(-4)}</span>
            <button onClick={logout}>Logout</button>
          </div>
        ) : (
          <button onClick={login}>Login with Internet Identity</button>
        )}
      </header>
      
      <main>
        {isAuthenticated ? (
          <UploadForm />
        ) : (
          <p>Please login to mint NFTs</p>
        )}
      </main>
    </div>
  );
}

export default App;
