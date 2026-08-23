'use client';

import { Bell, Search, Menu } from 'lucide-react';
import { useAuth } from '@/components/providers/AuthProvider';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

export function Header() {
  const { user } = useAuth();

  return (
    <header className="flex h-16 items-center gap-4 border-b bg-background px-6">
      <Button variant="ghost" size="icon" className="md:hidden">
        <Menu className="h-6 w-6" />
      </Button>

      <div className="flex flex-1 items-center gap-4">
        <div className="relative w-full max-w-sm hidden md:flex">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="search"
            placeholder="Search patients..."
            className="w-full pl-9 bg-muted/50 border-transparent focus-visible:bg-background"
          />
        </div>
      </div>

      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-5 w-5" />
          <span className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-destructive" />
        </Button>
        <div className="hidden md:flex items-center gap-2 border-l pl-4">
          {user?.profileImage ? (
            <img src={user.profileImage} alt="Profile" className="h-8 w-8 rounded-full object-cover border border-border" />
          ) : (
            <div className="h-8 w-8 rounded-full bg-primary/20 text-primary flex items-center justify-center font-bold">
              {user?.firstName?.charAt(0) || 'D'}
            </div>
          )}
          <div className="grid gap-0.5 text-sm leading-none">
            <span className="font-semibold text-sm">Dr. {user?.firstName} {user?.lastName}</span>
            <span className="text-xs text-muted-foreground">{user?.email}</span>
          </div>
        </div>
      </div>
    </header>
  );
}
