'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/components/providers/AuthProvider';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Loader2, CalendarX2, CheckCircle2, Clock } from 'lucide-react';
import { toast } from 'sonner';
import Link from 'next/link';

export default function AppointmentsPage() {
  const { user } = useAuth();
  const [appointments, setAppointments] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchAppointments() {
      try {
        const response = await api.get('/api/Doctor/get/appointments');
        if (response.data && response.data.appointmentDtos) {
          setAppointments(response.data.appointmentDtos);
        } else {
          setAppointments([]); // Empty if none found
        }
      } catch (error) {
        console.error('Failed to load appointments:', error);
        toast.error('Failed to load appointments');
      } finally {
        setIsLoading(false);
      }
    }

    if (user) {
      fetchAppointments();
    }
  }, [user]);

  const filterByStatus = (statuses: string[]) => {
    return appointments.filter(app => statuses.includes(app.status));
  };

  const renderTable = (filteredAppointments: any[], emptyMessage: string) => {
    if (filteredAppointments.length === 0) {
      return (
        <div className="flex flex-col items-center justify-center p-8 text-center text-muted-foreground border rounded-lg border-dashed">
          <CalendarX2 className="h-10 w-10 mb-4 opacity-50" />
          <p>{emptyMessage}</p>
        </div>
      );
    }

    return (
      <div className="rounded-md border">
        <div className="grid grid-cols-5 border-b bg-muted/50 p-3 text-sm font-medium text-muted-foreground">
          <div className="col-span-1">Patient Name</div>
          <div className="col-span-1">Date & Time</div>
          <div className="col-span-1">Type</div>
          <div className="col-span-1">Status</div>
          <div className="col-span-1 text-right">Actions</div>
        </div>
        <div className="divide-y">
          {filteredAppointments.map((app) => (
            <div key={app.id} className="grid grid-cols-5 items-center p-3 text-sm hover:bg-muted/30 transition-colors">
              <div className="col-span-1 font-medium">{app.patientName}</div>
              <div className="col-span-1">
                <div>{app.date}</div>
                <div className="text-muted-foreground text-xs">{app.time}</div>
              </div>
              <div className="col-span-1">{app.type}</div>
              <div className="col-span-1">
                <Badge variant={
                  app.status === 'Upcoming' ? 'default' :
                  app.status === 'Pending' ? 'secondary' : 'destructive'
                }>
                  {app.status}
                </Badge>
              </div>
              <div className="col-span-1 text-right space-x-2">
                <Button variant="outline" size="sm" asChild>
                  <Link href={`/patient-details/${app.patientId}`}>View</Link>
                </Button>
                {app.status === 'Pending' && (
                  <Button size="sm" onClick={() => toast.success('Appointment Confirmed!')}>
                    Confirm
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  if (isLoading) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-in fade-in duration-500 max-w-6xl mx-auto">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Appointments</h1>
          <p className="text-muted-foreground mt-1">
            Manage your schedule and patient consultations.
          </p>
        </div>
        <Button>+ New Appointment</Button>
      </div>

      <Tabs defaultValue="upcoming" className="space-y-4">
        <TabsList>
          <TabsTrigger value="upcoming" className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4" /> Upcoming
          </TabsTrigger>
          <TabsTrigger value="pending" className="flex items-center gap-2">
            <Clock className="h-4 w-4" /> Pending
          </TabsTrigger>
          <TabsTrigger value="missed" className="flex items-center gap-2">
            <CalendarX2 className="h-4 w-4" /> Missed
          </TabsTrigger>
        </TabsList>

        <TabsContent value="upcoming">
          <Card>
            <CardHeader>
              <CardTitle>Upcoming Appointments</CardTitle>
              <CardDescription>Confirmed consultations scheduled for the future.</CardDescription>
            </CardHeader>
            <CardContent>
              {renderTable(filterByStatus(['Upcoming', 'Confirmed']), 'No upcoming appointments scheduled.')}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="pending">
          <Card>
            <CardHeader>
              <CardTitle>Pending Requests</CardTitle>
              <CardDescription>Appointment requests waiting for your approval.</CardDescription>
            </CardHeader>
            <CardContent>
              {renderTable(filterByStatus(['Pending', 'Requested']), 'No pending appointment requests.')}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="missed">
          <Card>
            <CardHeader>
              <CardTitle>Missed / Cancelled</CardTitle>
              <CardDescription>Appointments that were missed or cancelled.</CardDescription>
            </CardHeader>
            <CardContent>
              {renderTable(filterByStatus(['Missed', 'Cancelled']), 'No missed appointments found.')}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
