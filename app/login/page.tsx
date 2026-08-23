'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { Loader2, Eye, EyeOff, Activity, UserRound } from 'lucide-react';
import { api } from '@/lib/api';
import { useAuth } from '@/components/providers/AuthProvider';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form';

const loginSchema = z.object({
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
});

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const form = useForm<z.infer<typeof loginSchema>>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
    },
  });

  async function onSubmit(values: z.infer<typeof loginSchema>) {
    setIsLoading(true);
    try {
      // Replicate the exact Blazor backend call
      const response = await api.post('/api/Auth/login', {
        email: values.email,
        password: values.password,
        profile_type: 'doctor'
      });

      if (response.data.isSuccess) {
        login(response.data.token || response.data.message || 'dummy_token', {
          id: response.data.user?.id || '',
          email: values.email,
          firstName: response.data.user?.firstName || '',
          lastName: response.data.user?.lastName || '',
          role: 'Doctor',
          profileImage: response.data.user?.profileImage || '',
        });
        
        toast.success('Login successful. Redirecting to dashboard...');
        
        router.push('/dashboard');
      } else {
        toast.error(response.data.message || 'Invalid credentials');
      }
    } catch (error: any) {
      toast.error(error.response?.data?.message || error.response?.data?.title || 'Failed to connect to the server.');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden bg-[#f0fdf4]">
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
            Health<span className="text-emerald-600">Verse</span>
          </h1>
          <p className="text-slate-500 mt-2 font-medium">
            Sign in to your clinical workspace
          </p>
        </div>

        {/* Main Card */}
        <div className="bg-white rounded-3xl shadow-2xl shadow-emerald-900/10 border border-slate-100 p-8 sm:p-10">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              
              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-slate-700 font-semibold">Email Address</FormLabel>
                    <FormControl>
                      <Input 
                        placeholder="doctor@healthverse.com" 
                        className="h-12 rounded-xl bg-slate-50/50 border-slate-200 focus:bg-white focus:border-emerald-500 focus:ring-emerald-500/20 transition-all text-slate-900 placeholder:text-slate-400" 
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage className="text-red-500 text-xs" />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <div className="flex items-center justify-between">
                      <FormLabel className="text-slate-700 font-semibold">Password</FormLabel>
                      <Link href="/forget-password" className="text-sm font-semibold text-emerald-600 hover:text-emerald-500 transition-colors">
                        Forgot password?
                      </Link>
                    </div>
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

              <Button 
                type="submit" 
                className="w-full h-12 rounded-xl text-base font-semibold bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-600/25 transition-all active:scale-[0.98]" 
                disabled={isLoading}
              >
                {isLoading ? (
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                ) : (
                  'Sign In'
                )}
              </Button>
            </form>
          </Form>
        </div>

        {/* Footer */}
        <p className="mt-8 text-center text-sm font-medium text-slate-500">
          Don&apos;t have an account?{' '}
          <Link href="/register" className="text-emerald-600 font-bold hover:text-emerald-500 transition-colors">
            Create an account
          </Link>
        </p>
      </div>
    </div>
  );
}
