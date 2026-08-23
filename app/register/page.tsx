'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Loader2, Eye, EyeOff, Stethoscope, ShieldCheck } from 'lucide-react';
import { api } from '@/lib/api';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';

const registerSchema = z.object({
  firstName: z.string().min(2, { message: 'First name is required' }),
  lastName: z.string().min(2, { message: 'Last name is required' }),
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(8, { message: 'Password must be at least 8 characters' })
    .regex(/[A-Z]/, { message: 'Password must contain at least one uppercase letter' })
    .regex(/[a-z]/, { message: 'Password must contain at least one lowercase letter' })
    .regex(/[0-9]/, { message: 'Password must contain at least one number' })
    .regex(/[^A-Za-z0-9]/, { message: 'Password must contain at least one special character' }),
  confirmPassword: z.string(),
  specialty: z.enum(['Ophthalmologist', 'Optometrist', 'Optician', 'Ocularist'], {
    required_error: "Please select a specialty.",
  }),
  address: z.string().optional(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

export default function RegisterPage() {
  const router = useRouter();
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const form = useForm<z.infer<typeof registerSchema>>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      firstName: '',
      lastName: '',
      email: '',
      password: '',
      confirmPassword: '',
      specialty: 'Ophthalmologist' as any,
      address: '',
    },
  });

  async function onSubmit(values: z.infer<typeof registerSchema>) {
    setIsLoading(true);
    try {
      // Replicate the exact Blazor backend call
      const response = await api.post('/api/Auth/register', {
        first_name: values.firstName,
        last_name: values.lastName,
        email: values.email,
        password: values.password,
        profile_type: "doctor",
        gender: "Not Specified",
        specialization: values.specialty, // Pass it just in case API allows it
        address: values.address || "Pending",
      });

      if (response.data.isSuccess || response.status === 200) {
        // Since specialization wasn't in original RegisterDto, we can update it immediately if we have a token
        if (response.data.token) {
          try {
            await api.post('/api/Doctor/profile/update', {
              specialization: values.specialty,
            }, {
              headers: { Authorization: `Bearer ${response.data.token}` }
            });
          } catch (e) {
            console.error("Failed to update specialty post-registration", e);
          }
        }

        toast.success('Registration successful. Please verify your email or login.');
        router.push('/login');
      } else {
        toast.error(response.data.message || 'Registration failed.');
      }
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to connect to the server.');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden bg-[#f0fdf4] py-12">
      {/* Subtle Background Elements */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] rounded-full bg-emerald-200/50 blur-[120px]" />
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] rounded-full bg-teal-200/50 blur-[120px]" />

      <div className="w-full max-w-md relative z-10 px-4">
        {/* Logo Section */}
        <div className="flex flex-col items-center mb-8 text-center">
          <div className="h-16 w-16 bg-white rounded-2xl shadow-xl shadow-emerald-900/5 flex items-center justify-center mb-6 border border-emerald-50">
            <Eye className="h-8 w-8 text-emerald-600" />
          </div>
          <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight">
            Create an Account
          </h1>
          <p className="text-slate-500 mt-2 font-medium">
            Join HealthVerse as a medical professional
          </p>
        </div>

        {/* Main Card */}
        <div className="bg-white rounded-3xl shadow-2xl shadow-emerald-900/10 border border-slate-100 p-8 sm:p-10">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="firstName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-slate-700 font-semibold">First Name</FormLabel>
                      <FormControl>
                        <Input placeholder="John" className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 placeholder:text-slate-400" {...field} />
                      </FormControl>
                      <FormMessage className="text-red-500 text-xs" />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="lastName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-slate-700 font-semibold">Last Name</FormLabel>
                      <FormControl>
                        <Input placeholder="Doe" className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 placeholder:text-slate-400" {...field} />
                      </FormControl>
                      <FormMessage className="text-red-500 text-xs" />
                    </FormItem>
                  )}
                />
              </div>

              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-slate-700 font-semibold">Email Address</FormLabel>
                    <FormControl>
                      <Input placeholder="doctor@healthverse.com" type="email" className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 placeholder:text-slate-400" {...field} />
                    </FormControl>
                    <FormMessage className="text-red-500 text-xs" />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="specialty"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-slate-700 font-semibold">Specialty</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900">
                          <SelectValue placeholder="Select your specialty" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="Ophthalmologist">Ophthalmologist</SelectItem>
                        <SelectItem value="Optometrist">Optometrist</SelectItem>
                        <SelectItem value="Optician">Optician</SelectItem>
                        <SelectItem value="Ocularist">Ocularist</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage className="text-red-500 text-xs" />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-slate-700 font-semibold">Password</FormLabel>
                    <FormControl>
                      <div className="relative">
                        <Input
                          type={showPassword ? 'text' : 'password'}
                          placeholder="••••••••"
                          className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 pr-12 placeholder:text-slate-400"
                          {...field}
                        />
                        <button
                          type="button"
                          className="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-md text-slate-400 hover:text-slate-600 transition-colors focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                          onClick={() => setShowPassword(!showPassword)}
                        >
                          {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                        </button>
                      </div>
                    </FormControl>
                    <FormMessage className="text-red-500 text-xs" />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="confirmPassword"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-slate-700 font-semibold">Confirm Password</FormLabel>
                    <FormControl>
                      <Input
                        type={showPassword ? 'text' : 'password'}
                        placeholder="••••••••"
                        className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 placeholder:text-slate-400"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage className="text-red-500 text-xs" />
                  </FormItem>
                )}
              />

              <Button 
                type="submit" 
                className="w-full h-12 rounded-xl text-base font-semibold bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-600/25 transition-all active:scale-[0.98] mt-2" 
                disabled={isLoading}
              >
                {isLoading ? (
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                ) : (
                  'Create Account'
                )}
              </Button>
            </form>
          </Form>
        </div>

        {/* Footer */}
        <p className="mt-8 text-center text-sm font-medium text-slate-500">
          Already have an account?{' '}
          <Link href="/login" className="text-emerald-600 font-bold hover:text-emerald-500 transition-colors">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
