'use client';

import { useState, useRef, useEffect, use } from 'react';
import { api } from '@/lib/api';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Loader2, UserCircle, Bot, Eye, Activity, FileText, Send } from 'lucide-react';
import { toast } from 'sonner';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import { useAuth } from '@/components/providers/AuthProvider';

export default function PatientDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: patientId } = use(params);
  const { user } = useAuth();
  
  const [patient, setPatient] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isGeneratingPdf, setIsGeneratingPdf] = useState(false);
  const prescriptionRef = useRef<HTMLDivElement>(null);

  // Chat State
  const [chatMessages, setChatMessages] = useState<{role: string, content: string}[]>([
    { role: 'doctor', content: 'Hello, how have your eyes been feeling since your last visit?' },
    { role: 'patient', content: 'A bit dry in the evenings, but the blurry vision is gone.' }
  ]);
  const [chatInput, setChatInput] = useState('');
  
  // AI Agent State
  const [aiMessages, setAiMessages] = useState<{role: 'human' | 'ai', content: string}[]>([]);
  const [aiInput, setAiInput] = useState('');
  const [isAiLoading, setIsAiLoading] = useState(false);

  // DR Analysis State
  const [isUploadingDR, setIsUploadingDR] = useState(false);
  const [drResult, setDrResult] = useState<any>(null);
  const [drImagePreview, setDrImagePreview] = useState<string | null>(null);

  // Classifier State
  const [isUploadingClassifier, setIsUploadingClassifier] = useState(false);
  const [classifierResult, setClassifierResult] = useState<any>(null);
  const [classifierImagePreview, setClassifierImagePreview] = useState<string | null>(null);

  useEffect(() => {
    // Mock Fetch Patient
    setTimeout(() => {
      setPatient({
        id: patientId,
        name: 'John Doe',
        age: 45,
        gender: 'Male',
        phone: '+1 234 567 890',
        bloodGroup: 'O+',
        allergies: 'None',
        medicalHistory: 'Hypertension, Mild Glaucoma',
      });
      setIsLoading(false);
    }, 800);
  }, [patientId]);

  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!chatInput.trim()) return;
    setChatMessages([...chatMessages, { role: 'doctor', content: chatInput }]);
    setChatInput('');
    // TODO: Send to backend API
  };

  const handleSendAiMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!aiInput.trim()) return;

    const userMessage: {role: 'human' | 'ai', content: string} = { role: 'human', content: aiInput };
    setAiMessages(prev => [...prev, userMessage]);
    setAiInput('');
    setIsAiLoading(true);

    try {
      const specialist = user?.specialty || 'ophthalmologist';
      const res = await fetch(`http://localhost:8001/chat/${specialist.toLowerCase()}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: [...aiMessages, userMessage].map(m => ({ type: m.role, content: m.content })),
          patient_id: patientId
        })
      });

      if (!res.ok) throw new Error('Failed to get response');
      const data = await res.json();
      setAiMessages(prev => [...prev, { role: 'ai', content: data.response }]);
    } catch (error) {
      console.error(error);
      toast.error("Failed to connect to the AI Agent.");
      setAiMessages(prev => [...prev, { role: 'ai', content: `I'm currently in demo mode. You said: "${userMessage.content}".` }]);
    } finally {
      setIsAiLoading(false);
    }
  };

  const handleDRImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setDrImagePreview(URL.createObjectURL(file));
    setIsUploadingDR(true);
    setDrResult(null);

    try {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await fetch('https://zamliskill--dr-efficientnetb7-api-fastapi-app.modal.run/predict', {
        method: 'POST',
        body: formData
      });
      
      if (!response.ok) throw new Error('Prediction failed');
      const result = await response.json();
      setDrResult(result);
      toast.success('DR Analysis complete!');
    } catch (error) {
      console.error(error);
      toast.error('Failed to analyze image for DR');
    } finally {
      setIsUploadingDR(false);
    }
  };

  const handleClassifierImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setClassifierImagePreview(URL.createObjectURL(file));
    setIsUploadingClassifier(true);
    setClassifierResult(null);

    try {
      const formData = new FormData();
      formData.append('file', file);
      
      const response = await fetch('https://waseerusman2--eye-disease-classifier-fastapi-app.modal.run/predict', {
        method: 'POST',
        body: formData
      });
      
      if (!response.ok) throw new Error('Classification failed');
      const result = await response.json();
      setClassifierResult(result);
      toast.success('Disease Classification complete!');
    } catch (error) {
      console.error(error);
      toast.error('Failed to classify image');
    } finally {
      setIsUploadingClassifier(false);
    }
  };

  const generatePrescriptionPDF = async () => {
    if (!prescriptionRef.current || !patient || !user) return;
    setIsGeneratingPdf(true);
    
    try {
      const canvas = await html2canvas(prescriptionRef.current, { scale: 2 });
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = (canvas.height * pdfWidth) / canvas.width;
      
      pdf.addImage(imgData, 'PNG', 0, 0, pdfWidth, pdfHeight);
      pdf.save(`Prescription_${patient.name.replace(' ', '_')}.pdf`);
      toast.success('Prescription generated successfully!');
    } catch (error) {
      console.error(error);
      toast.error('Failed to generate PDF');
    } finally {
      setIsGeneratingPdf(false);
    }
  };

  if (isLoading || !patient) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-in fade-in duration-500 max-w-6xl mx-auto pb-20">
      {/* Header Info */}
      <Card className="border-t-4 border-t-primary">
        <CardContent className="pt-6">
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <div className="flex items-center gap-4">
              <UserCircle className="h-16 w-16 text-muted-foreground" />
              <div>
                <h2 className="text-2xl font-bold">{patient.name}</h2>
                <div className="flex flex-wrap gap-2 mt-1 text-sm text-muted-foreground">
                  <span>ID: {patient.id}</span> • 
                  <span>{patient.age} yrs, {patient.gender}</span> • 
                  <span>Blood: {patient.bloodGroup}</span>
                </div>
              </div>
            </div>
            <div className="flex gap-2">
              <Button onClick={generatePrescriptionPDF} disabled={isGeneratingPdf}>
                {isGeneratingPdf ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <FileText className="mr-2 h-4 w-4" />}
                Generate Prescription
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Main Tabs Workspace */}
      <Tabs defaultValue="chat" className="space-y-4">
        <TabsList className="grid w-full grid-cols-4 lg:w-[600px]">
          <TabsTrigger value="chat"><UserCircle className="mr-2 h-4 w-4" /> Patient Chat</TabsTrigger>
          <TabsTrigger value="ai"><Bot className="mr-2 h-4 w-4" /> AI Agent</TabsTrigger>
          <TabsTrigger value="dr"><Eye className="mr-2 h-4 w-4" /> DR Analysis</TabsTrigger>
          <TabsTrigger value="classifier"><Activity className="mr-2 h-4 w-4" /> Classifier</TabsTrigger>
        </TabsList>

        <TabsContent value="chat" className="space-y-4">
          <Card className="h-[600px] flex flex-col">
            <CardHeader>
              <CardTitle>Direct Message</CardTitle>
              <CardDescription>Chat directly with {patient.name}</CardDescription>
            </CardHeader>
            <CardContent className="flex-1 overflow-y-auto space-y-4">
              {chatMessages.map((msg, i) => (
                <div key={i} className={`flex ${msg.role === 'doctor' ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[70%] rounded-lg px-4 py-2 ${
                    msg.role === 'doctor' 
                      ? 'bg-primary text-primary-foreground' 
                      : 'bg-muted text-foreground'
                  }`}>
                    {msg.content}
                  </div>
                </div>
              ))}
            </CardContent>
            <div className="p-4 border-t mt-auto">
              <form onSubmit={handleSendMessage} className="flex gap-2">
                <Input 
                  value={chatInput}
                  onChange={(e) => setChatInput(e.target.value)}
                  placeholder="Type your message..." 
                  className="flex-1"
                />
                <Button type="submit" size="icon"><Send className="h-4 w-4" /></Button>
              </form>
            </div>
          </Card>
        </TabsContent>

        <TabsContent value="ai" className="space-y-4">
          <Card className="h-[600px] flex flex-col">
            <CardHeader className="border-b bg-muted/20 pb-4">
              <div className="flex justify-between items-center">
                <div>
                  <CardTitle className="flex items-center gap-2">
                    <Bot className="h-5 w-5 text-primary" />
                    AI {user?.specialty || 'Ophthalmologist'} Agent
                  </CardTitle>
                  <CardDescription>Assisting with patient: {patient.name}</CardDescription>
                </div>
                <Badge variant="outline" className="bg-green-100 text-green-800 border-green-200">Online</Badge>
              </div>
            </CardHeader>
            <CardContent className="flex-1 overflow-y-auto p-6 space-y-6">
              {aiMessages.length === 0 && (
                <div className="flex flex-col items-center justify-center h-full text-center space-y-4 text-muted-foreground">
                  <Bot className="h-12 w-12 opacity-50" />
                  <p>Start a conversation with the AI Agent regarding this patient.</p>
                </div>
              )}
              {aiMessages.map((msg, i) => (
                <div key={i} className={`flex ${msg.role === 'human' ? 'justify-end' : 'justify-start'}`}>
                  {msg.role === 'ai' && (
                    <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center mr-3 mt-1 flex-shrink-0">
                      <Bot className="h-4 w-4 text-primary" />
                    </div>
                  )}
                  <div className={`max-w-[80%] rounded-2xl px-5 py-3 ${
                    msg.role === 'human' 
                      ? 'bg-primary text-primary-foreground rounded-tr-sm' 
                      : 'bg-muted text-foreground rounded-tl-sm shadow-sm border border-border/50'
                  }`}>
                    <div className="whitespace-pre-wrap">{msg.content}</div>
                  </div>
                  {msg.role === 'human' && (
                    <div className="h-8 w-8 rounded-full bg-slate-200 dark:bg-slate-800 flex items-center justify-center ml-3 mt-1 flex-shrink-0">
                      <UserCircle className="h-5 w-5 text-slate-500" />
                    </div>
                  )}
                </div>
              ))}
              {isAiLoading && (
                <div className="flex justify-start">
                  <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center mr-3 mt-1 flex-shrink-0">
                    <Bot className="h-4 w-4 text-primary" />
                  </div>
                  <div className="bg-muted text-foreground rounded-2xl rounded-tl-sm px-5 py-3 shadow-sm border border-border/50 flex items-center gap-2">
                    <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                    <span className="text-sm text-muted-foreground">Thinking...</span>
                  </div>
                </div>
              )}
            </CardContent>
            <div className="p-4 bg-background border-t mt-auto">
              <form onSubmit={handleSendAiMessage} className="relative flex items-center">
                <Input 
                  value={aiInput}
                  onChange={(e) => setAiInput(e.target.value)}
                  placeholder={`Ask the AI ${user?.specialty || 'specialist'}...`} 
                  className="pr-12 py-6 rounded-full shadow-sm"
                  disabled={isAiLoading}
                />
                <Button 
                  type="submit" 
                  size="icon" 
                  className="absolute right-1.5 h-9 w-9 rounded-full" 
                  disabled={isAiLoading || !aiInput.trim()}
                >
                  <Send className="h-4 w-4" />
                </Button>
              </form>
            </div>
          </Card>
        </TabsContent>

        <TabsContent value="dr">
          <Card>
            <CardHeader>
              <CardTitle>Diabetic Retinopathy Analysis</CardTitle>
              <CardDescription>Upload retinal fundus images for immediate DR staging analysis.</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="flex flex-col items-center justify-center p-8 border border-dashed rounded-lg text-center bg-muted/20 hover:bg-muted/50 transition-colors">
                  <Input 
                    type="file" 
                    accept="image/*" 
                    className="hidden" 
                    id="dr-upload" 
                    onChange={handleDRImageUpload}
                    disabled={isUploadingDR}
                  />
                  <label htmlFor="dr-upload" className="cursor-pointer flex flex-col items-center">
                    {isUploadingDR ? (
                      <Loader2 className="h-10 w-10 animate-spin text-primary mb-4" />
                    ) : (
                      <Eye className="h-10 w-10 text-muted-foreground mb-4 opacity-50" />
                    )}
                    <span className="text-sm font-medium">Click to upload fundus image</span>
                    <span className="text-xs text-muted-foreground mt-1">JPEG, PNG only</span>
                  </label>
                </div>
                <div>
                  {drImagePreview && (
                    <div className="mb-4 rounded-md overflow-hidden border">
                      <img src={drImagePreview} alt="DR Preview" className="w-full h-48 object-cover" />
                    </div>
                  )}
                  {drResult && (
                    <div className="p-4 bg-muted rounded-md border">
                      <h4 className="font-semibold mb-2">Analysis Results</h4>
                      <div className="flex justify-between py-1 border-b">
                        <span className="text-muted-foreground text-sm">Prediction:</span>
                        <span className="font-medium text-sm">{drResult.prediction || drResult.class_name}</span>
                      </div>
                      <div className="flex justify-between py-1">
                        <span className="text-muted-foreground text-sm">Confidence:</span>
                        <span className="font-medium text-sm text-primary">
                          {drResult.confidence ? (drResult.confidence * 100).toFixed(2) + '%' : 'N/A'}
                        </span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="classifier">
          <Card>
            <CardHeader>
              <CardTitle>Eye Disease Classifier</CardTitle>
              <CardDescription>Multi-class classification tool for common anterior and posterior segment diseases.</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="flex flex-col items-center justify-center p-8 border border-dashed rounded-lg text-center bg-muted/20 hover:bg-muted/50 transition-colors">
                  <Input 
                    type="file" 
                    accept="image/*" 
                    className="hidden" 
                    id="classifier-upload" 
                    onChange={handleClassifierImageUpload}
                    disabled={isUploadingClassifier}
                  />
                  <label htmlFor="classifier-upload" className="cursor-pointer flex flex-col items-center">
                    {isUploadingClassifier ? (
                      <Loader2 className="h-10 w-10 animate-spin text-primary mb-4" />
                    ) : (
                      <Activity className="h-10 w-10 text-muted-foreground mb-4 opacity-50" />
                    )}
                    <span className="text-sm font-medium">Click to upload eye image</span>
                    <span className="text-xs text-muted-foreground mt-1">JPEG, PNG only</span>
                  </label>
                </div>
                <div>
                  {classifierImagePreview && (
                    <div className="mb-4 rounded-md overflow-hidden border">
                      <img src={classifierImagePreview} alt="Classifier Preview" className="w-full h-48 object-cover" />
                    </div>
                  )}
                  {classifierResult && (
                    <div className="p-4 bg-muted rounded-md border">
                      <h4 className="font-semibold mb-2">Analysis Results</h4>
                      <div className="flex justify-between py-1 border-b">
                        <span className="text-muted-foreground text-sm">Condition:</span>
                        <span className="font-medium text-sm">{classifierResult.prediction || classifierResult.class_name}</span>
                      </div>
                      <div className="flex justify-between py-1">
                        <span className="text-muted-foreground text-sm">Confidence:</span>
                        <span className="font-medium text-sm text-primary">
                          {classifierResult.confidence ? (classifierResult.confidence * 100).toFixed(2) + '%' : 'N/A'}
                        </span>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Hidden element for PDF generation */}
      <div style={{ position: 'absolute', top: '-9999px', left: '-9999px' }}>
        <div ref={prescriptionRef} style={{ width: '800px', padding: '40px', backgroundColor: 'white', color: 'black', fontFamily: 'sans-serif' }}>
          <div style={{ borderBottom: '2px solid #198754', paddingBottom: '20px', marginBottom: '20px', display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <h1 style={{ color: '#198754', margin: 0, fontSize: '28px' }}>HealthVerse Clinic</h1>
              <p style={{ margin: '5px 0' }}>Dr. {user?.firstName} {user?.lastName}</p>
              <p style={{ margin: '0' }}>Ophthalmology</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p style={{ margin: '0' }}>Date: {new Date().toLocaleDateString()}</p>
            </div>
          </div>
          <div style={{ marginBottom: '30px' }}>
            <h3 style={{ borderBottom: '1px solid #ccc', paddingBottom: '5px' }}>Patient Details</h3>
            <p><strong>Name:</strong> {patient.name} &nbsp;&nbsp;&nbsp; <strong>Age/Gender:</strong> {patient.age} / {patient.gender}</p>
          </div>
          <div style={{ minHeight: '300px' }}>
            <h1 style={{ fontSize: '40px', fontFamily: 'serif', margin: '0 0 20px 0' }}>Rx</h1>
            {/* Prescription body goes here */}
            <p style={{ marginTop: '20px', lineHeight: '2' }}>
              1. Moxifloxacin Eye Drops 0.5% (1 drop, 3 times a day)<br/>
              2. Artificial Tears (As needed for dryness)
            </p>
          </div>
          <div style={{ borderTop: '1px solid #ccc', paddingTop: '20px', marginTop: '50px', textAlign: 'right' }}>
            <p style={{ margin: 0 }}>_________________________</p>
            <p style={{ margin: '5px 0 0 0' }}>Doctor's Signature</p>
          </div>
        </div>
      </div>
    </div>
  );
}
