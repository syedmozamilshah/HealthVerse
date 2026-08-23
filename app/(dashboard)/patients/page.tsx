'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useAuth } from '@/components/providers/AuthProvider';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Loader2, Search, ArrowRight } from 'lucide-react';
import { toast } from 'sonner';
import Link from 'next/link';

export default function PatientsPage() {
  const { user } = useAuth();
  const [patients, setPatients] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    async function fetchPatients() {
      try {
        const response = await api.get(`/api/Patient/doctor/${user?.id || 'all'}`);
        if (response.data && response.data.patients) {
          setPatients(response.data.patients);
        } else {
          // Mock data
          setPatients([
            { id: 'p1', name: 'John Doe', age: 45, gender: 'Male', lastVisit: '2026-08-20', condition: 'Glaucoma Suspect' },
            { id: 'p2', name: 'Alice Smith', age: 32, gender: 'Female', lastVisit: '2026-08-15', condition: 'Myopia' },
            { id: 'p3', name: 'Robert Johnson', age: 60, gender: 'Male', lastVisit: '2026-07-30', condition: 'Cataract' },
            { id: 'p4', name: 'Emma Wilson', age: 28, gender: 'Female', lastVisit: '2026-08-10', condition: 'Dry Eye Syndrome' },
          ]);
        }
      } catch (error) {
        console.error('Failed to load patients:', error);
        toast.error('Failed to load patient list');
      } finally {
        setIsLoading(false);
      }
    }

    if (user) {
      fetchPatients();
    }
  }, [user]);

  const filteredPatients = patients.filter(p => 
    p.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    p.condition?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-6 animate-in fade-in duration-500 max-w-6xl mx-auto">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Patients</h1>
          <p className="text-muted-foreground mt-1">
            Browse and manage your patient records.
          </p>
        </div>
        <div className="relative w-64">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            type="search"
            placeholder="Search patients..."
            className="w-full pl-9"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>All Patients</CardTitle>
          <CardDescription>A complete list of patients under your care.</CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="flex justify-center p-8">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
            </div>
          ) : (
            <div className="rounded-md border">
              <div className="grid grid-cols-5 border-b bg-muted/50 p-3 text-sm font-medium text-muted-foreground">
                <div className="col-span-1">Name</div>
                <div className="col-span-1">Demographics</div>
                <div className="col-span-1">Primary Condition</div>
                <div className="col-span-1">Last Visit</div>
                <div className="col-span-1 text-right">Actions</div>
              </div>
              <div className="divide-y">
                {filteredPatients.length > 0 ? (
                  filteredPatients.map((patient) => (
                    <div key={patient.id} className="grid grid-cols-5 items-center p-3 text-sm hover:bg-muted/30 transition-colors">
                      <div className="col-span-1 font-medium">{patient.name}</div>
                      <div className="col-span-1 text-muted-foreground">
                        {patient.age} yrs • {patient.gender}
                      </div>
                      <div className="col-span-1">{patient.condition || 'N/A'}</div>
                      <div className="col-span-1 text-muted-foreground">{patient.lastVisit}</div>
                      <div className="col-span-1 text-right">
                        <Button variant="ghost" size="sm" asChild>
                          <Link href={`/patient-details/${patient.id}`}>
                            View Details <ArrowRight className="ml-1 h-3 w-3" />
                          </Link>
                        </Button>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="p-8 text-center text-muted-foreground">
                    No patients found matching your search.
                  </div>
                )}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
