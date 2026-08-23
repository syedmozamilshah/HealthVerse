'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { api } from '@/lib/api';

interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  specialty?: string;
  profileImage?: string;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  login: (token: string, userData: User) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  isLoading: true,
  login: () => {},
  logout: () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if user is logged in on mount
    const checkAuth = async () => {
      try {
        const response = await api.get('/api/Doctor/get/profile');
        if (response.data && !response.data.isError) {
          setUser({
            id: response.data.doctor.id,
            email: response.data.doctor.email,
            firstName: response.data.doctor.firstName,
            lastName: response.data.doctor.lastName,
            role: 'Doctor',
            specialty: response.data.doctor.specialization || 'ophthalmologist',
            profileImage: response.data.doctor.profileImage || '',
          });
        }
      } catch (error) {
        // Not authenticated
        setUser(null);
      } finally {
        setIsLoading(false);
      }
    };
    
    checkAuth();
  }, []);

  const login = (token: string, userData: User) => {
    localStorage.setItem('jwt_token', token);
    setUser(userData);
  };

  const logout = () => {
    localStorage.removeItem('jwt_token');
    // Call backend logout if it exists, or just clear local state
    setUser(null);
    window.location.href = '/login';
  };

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
