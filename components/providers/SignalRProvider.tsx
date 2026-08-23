'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import * as signalR from '@microsoft/signalr';
import { useAuth } from './AuthProvider';
import { toast } from 'sonner';

interface SignalRContextType {
  connection: signalR.HubConnection | null;
  isConnected: boolean;
}

const SignalRContext = createContext<SignalRContextType>({
  connection: null,
  isConnected: false,
});

export function SignalRProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [connection, setConnection] = useState<signalR.HubConnection | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!user) {
      if (connection) {
        connection.stop();
        setConnection(null);
        setIsConnected(false);
      }
      return;
    }

    const token = typeof window !== 'undefined' ? localStorage.getItem('jwt_token') || '' : '';

    const newConnection = new signalR.HubConnectionBuilder()
      .withUrl(process.env.NEXT_PUBLIC_API_URL ? `${process.env.NEXT_PUBLIC_API_URL}/hubs/appointment` : 'http://localhost:5257/hubs/appointment', {
        accessTokenFactory: () => token
      })
      .withAutomaticReconnect()
      .build();

    setConnection(newConnection);
  }, [user]);

  useEffect(() => {
    if (connection) {
      connection.start()
        .then(() => {
          setIsConnected(true);
          console.log('SignalR Connected!');
          
          // The old Blazor app used specific methods, e.g., "ReceiveNotification"
          connection.on('ReceiveNotification', (message: string) => {
            toast.info(`Notification: ${message}`);
          });

          // Join doctor's specific group using their ID
          if (user?.id) {
            connection.invoke('JoinDoctorGroup', user.id).catch(err => console.error(err));
          }
        })
        .catch(e => {
          console.error('SignalR Connection Error: ', e);
          toast.error('Failed to connect to real-time notification server.');
        });

      connection.onreconnected(() => {
        setIsConnected(true);
        if (user?.id) {
          connection.invoke('JoinDoctorGroup', user.id).catch(err => console.error(err));
        }
      });

      connection.onreconnecting(() => setIsConnected(false));
      connection.onclose(() => setIsConnected(false));
    }

    return () => {
      if (connection) {
        connection.off('ReceiveNotification');
        connection.stop();
      }
    };
  }, [connection, user]);

  return (
    <SignalRContext.Provider value={{ connection, isConnected }}>
      {children}
    </SignalRContext.Provider>
  );
}

export const useSignalR = () => useContext(SignalRContext);
