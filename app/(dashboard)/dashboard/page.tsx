'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/components/providers/AuthProvider';
import { api } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Users, Calendar as CalendarIcon, ClipboardList, Activity, ArrowRight, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import Link from 'next/link';

interface DashboardStats {
  totalPatients: number;
  todayAppointments: number;
  pendingReviews: number;
  activeSessions: number;
}

export default function DashboardPage() {
  const { user } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recentPatients, setRecentPatients] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchDashboardData() {
      try {
        // Here we'll call the actual first_api endpoints. 
        // For now, if the endpoints don't strictly exist with this exact response shape, we gracefully fallback.
        const [profileRes, appointmentsRes] = await Promise.all([
          api.get('/api/Doctor/get/profile').catch(() => null),
          api.get('/api/Doctor/get/appointments').catch(() => null)
        ]);
        
        const appointments = appointmentsRes?.data?.appointmentDtos || [];
        const today = new Date().setHours(0,0,0,0);
        
        const todayAppointments = appointments.filter((a: any) => {
          const d = new Date(a.appointmentDate).setHours(0,0,0,0);
          return d === today;
        });

        const pendingReviews = appointments.filter((a: any) => 
          a.status?.toLowerCase() === 'pending'
        ).length;

        // Unique patients from appointments
        const uniquePatients = new Set(appointments.map((a: any) => a.patientId)).size;

        setStats({
          totalPatients: uniquePatients || 0,
          todayAppointments: todayAppointments.length,
          pendingReviews: pendingReviews,
          activeSessions: 0,
        });

        // Use the appointments list to form recent patients
        const recent = appointments
          .slice(0, 5) // Take top 5
          .map((a: any) => ({
            id: a.patientId,
            name: a.patientName || `Patient ${a.patientId.substring(0, 4)}`,
            lastVisit: new Date(a.appointmentDate).toLocaleDateString(),
            status: a.status || 'Unknown'
          }));

        setRecentPatients(recent.length ? recent : [
          // Fallback if truly 0 appointments
        ]);
      } catch (error) {
        console.error('Failed to load dashboard data', error);
      } finally {
        setIsLoading(false);
      }
    }

    if (user) {
      fetchDashboardData();
    }
  }, [user]);

  if (isLoading) {
    return (
      <div className="flex h-full min-h-[400px] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
        <p className="text-muted-foreground mt-1">
          Welcome back, Dr. {user?.lastName || user?.firstName}. Here's an overview of your practice.
        </p>
      </div>
      
      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card className="shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Patients</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-primary">{stats?.totalPatients || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">+2 from last month</p>
          </CardContent>
        </Card>
        
        <Card className="shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Today's Appointments</CardTitle>
            <CalendarIcon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.todayAppointments || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">Next at 10:30 AM</p>
          </CardContent>
        </Card>
        
        <Card className="shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Reviews</CardTitle>
            <ClipboardList className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-amber-500">{stats?.pendingReviews || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">AI triages awaiting approval</p>
          </CardContent>
        </Card>

        <Card className="shadow-sm">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Sessions</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-500">{stats?.activeSessions || 0}</div>
            <p className="text-xs text-muted-foreground mt-1">Currently in-progress</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 grid-cols-1 md:grid-cols-3 lg:grid-cols-7">
        {/* Recent Patients Table */}
        <Card className="col-span-1 md:col-span-2 lg:col-span-5 shadow-sm">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>Recent Patients</CardTitle>
                <CardDescription>Your recently viewed or updated patient records.</CardDescription>
              </div>
              <Button variant="outline" size="sm" asChild>
                <Link href="/patients">View All</Link>
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div className="rounded-md border">
              {/* Note: We will replace this with a proper Shadcn Table once it's installed */}
              <div className="grid grid-cols-4 border-b bg-muted/50 p-3 text-sm font-medium text-muted-foreground">
                <div className="col-span-1">Name</div>
                <div className="col-span-1">Last Visit</div>
                <div className="col-span-1">Status</div>
                <div className="col-span-1 text-right">Action</div>
              </div>
              {recentPatients.map((patient) => (
                <div key={patient.id} className="grid grid-cols-4 items-center border-b p-3 text-sm last:border-0 hover:bg-muted/30 transition-colors">
                  <div className="col-span-1 font-medium">{patient.name}</div>
                  <div className="col-span-1 text-muted-foreground">{patient.lastVisit}</div>
                  <div className="col-span-1">
                    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                      patient.status === 'Active' ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                      patient.status === 'Pending' ? 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200' :
                      'bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-300'
                    }`}>
                      {patient.status}
                    </span>
                  </div>
                  <div className="col-span-1 text-right">
                    <Button variant="ghost" size="sm" asChild>
                      <Link href={`/patient-details/${patient.id}`}>
                        View <ArrowRight className="ml-1 h-3 w-3" />
                      </Link>
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Quick Actions */}
        <Card className="col-span-1 lg:col-span-2 shadow-sm">
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
            <CardDescription>Frequently used tools</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <Button className="w-full justify-start" variant="outline" asChild>
              <Link href="/appointments">
                <CalendarIcon className="mr-2 h-4 w-4" />
                View Schedule
              </Link>
            </Button>
            <Button className="w-full justify-start" variant="outline" asChild>
              <Link href="/ai-chat">
                <Activity className="mr-2 h-4 w-4" />
                Start AI Triage
              </Link>
            </Button>
            <Button className="w-full justify-start text-primary border-primary/20 hover:bg-primary/10" variant="outline" asChild>
              <Link href="/profile-setup">
                <Users className="mr-2 h-4 w-4" />
                Update Availability
              </Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
