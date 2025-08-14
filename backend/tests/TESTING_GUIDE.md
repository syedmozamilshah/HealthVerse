# Testing & Deployment Guide

## 🧪 Testing the Ophthalmology Assistant System

This guide provides comprehensive instructions for testing the system before deployment.

### Prerequisites

1. **API Keys Setup**: Configure your environment variables in `backend/.env`
2. **Dependencies**: Install all required dependencies
3. **Qdrant Instance**: Have a running Qdrant vector database

### Step-by-Step Testing Process

#### 1. Structure Validation (No API Keys Required)

```bash
# Run mock tests to validate system structure
python test_system_mock.py
```

This will test:
- ✅ Module imports and configuration
- ✅ Doctor type validation (4 specialists only)
- ✅ Mock question generation logic
- ✅ Mock doctor identification logic  
- ✅ Mock summary generation
- ✅ Frontend file structure

#### 2. Environment Setup

Configure your `backend/.env` file:

```bash
# Google Gemini Configuration
GOOGLE_API_KEY=your_actual_gemini_api_key

# Qdrant Configuration  
QDRANT_ENDPOINT=https://your-qdrant-instance.qdrant.io
QDRANT_API_KEY=your_qdrant_api_key
QDRANT_COLLECTION_NAME=ophthalmology_knowledge

# Embedding Model (Gemini)
EMBEDDING_MODEL=models/embedding-001

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=True

# CORS Configuration
ALLOWED_ORIGINS=["http://localhost:3000", "http://127.0.0.1:3000"]
```

#### 3. Install Dependencies

```bash
# Backend dependencies
cd backend
pip install -r requirements.txt

# Frontend dependencies  
cd ../frontend
npm install
```

#### 4. Start the Backend Server

```bash
cd backend
python main.py
```

Expected output:
```
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

#### 5. Test API Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Expected response:
{
  "status": "healthy",
  "version": "1.0.0", 
  "services": {
    "qdrant": "connected",
    "gemini": "configured"
  }
}
```

#### 6. Setup Test Data (Optional)

```bash
# Populate Qdrant with sample medical knowledge
python setup_test_data.py
```

Expected output:
```
📚 Setting up test data in Qdrant vector store...
✅ Document 1/12: refractive_errors
✅ Document 2/12: glaucoma
...
🎉 All test data uploaded successfully!
```

#### 7. Run Comprehensive API Tests

```bash
# Test all endpoints with mock user inputs
python test_api_endpoints.py
```

This will test:
- ✅ Health check endpoint
- ✅ Allowed doctors endpoint
- ✅ Question generation with realistic conditions
- ✅ Answer processing with mock responses  
- ✅ Doctor recommendations validation
- ✅ Medical summary generation

#### 8. Start Frontend and Manual Testing

```bash
cd frontend
npm start
```

Frontend available at: `http://localhost:3000`

**Manual Test Cases:**

1. **Blurry Vision Case**
   - Input: "I have blurry vision and headaches when using the computer"
   - Expected: Questions about duration, symptoms, activities
   - Expected Doctor: Optometrist or Ophthalmologist

2. **Emergency Case**  
   - Input: "Sudden severe eye pain with nausea and vision loss"
   - Expected: Questions about onset, severity, associated symptoms
   - Expected Doctor: Ophthalmologist or Ocular Surgeon

3. **Glasses Case**
   - Input: "I need new glasses, my prescription seems wrong"  
   - Expected: Questions about current glasses, vision problems
   - Expected Doctor: Optometrist or Optician

#### 9. Frontend Feature Testing

Test these specific features:

- ✅ **Dynamic Question Rendering**: Questions change based on input
- ✅ **Answer Options**: Each question has 3-4 options + "Other"
- ✅ **Other Option**: Clicking "Other" shows text input box
- ✅ **Custom Answers**: Text input works properly
- ✅ **Response Validation**: All questions must be answered
- ✅ **Final Results**: Doctor recommendation and summary display
- ✅ **Responsive Design**: Works on mobile and desktop
- ✅ **Print Functionality**: Summary can be printed

### Expected Test Results

#### Successful Question Generation Response:
```json
{
  "questions": [
    {
      "question": "How long have you been experiencing these symptoms?",
      "options": [
        {"text": "Less than a week", "is_other": false},
        {"text": "1-4 weeks", "is_other": false}, 
        {"text": "More than a month", "is_other": false},
        {"text": "Other", "is_other": true}
      ]
    }
  ]
}
```

#### Successful Final Response:
```json
{
  "doctor": {
    "doctor_type": "Optometrist",
    "reasoning": "Based on the symptoms of blurry vision and computer-related eye strain, an optometrist specializing in vision correction and digital eye strain would be most appropriate."
  },
  "summary_for_doctor": "Patient presents with blurry vision and headaches associated with computer use for the past 2 weeks. Reports mild discomfort, primarily during reading and screen time. Symptoms suggest possible digital eye strain or refractive error. Recommend comprehensive eye examination including refraction assessment."
}
```

## 🚀 Deployment Guide

### Production Environment Setup

#### 1. Backend Deployment

**Update Configuration for Production:**

```bash
# backend/.env
DEBUG=False
HOST=0.0.0.0
PORT=8000
ALLOWED_ORIGINS=["https://yourdomain.com", "https://www.yourdomain.com"]
```

**Deploy with Gunicorn:**

```bash
pip install gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

**Or with Docker:**

```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install -r requirements.txt
COPY backend/ .
EXPOSE 8000
CMD ["gunicorn", "main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
```

#### 2. Frontend Deployment

```bash
cd frontend

# Build for production
npm run build

# Deploy the build/ folder to your web server
# For nginx, copy to /var/www/html/
# For Apache, copy to /var/www/html/
# For cloud services, upload to S3, Netlify, Vercel, etc.
```

**Nginx Configuration Example:**

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    # Frontend
    location / {
        root /var/www/html;
        try_files $uri $uri/ /index.html;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### 3. Database and Vector Store

**Qdrant Cloud Setup:**
- Create account at [Qdrant Cloud](https://cloud.qdrant.io)
- Create cluster and get endpoint/API key
- Update `.env` with production credentials

**Local Qdrant with Docker:**
```bash
docker run -p 6333:6333 -v $(pwd)/qdrant_storage:/qdrant/storage qdrant/qdrant
```

#### 4. SSL/HTTPS Setup

```bash
# Using Certbot for Let's Encrypt
sudo certbot --nginx -d yourdomain.com
```

### Performance Optimization

1. **Backend Optimization:**
   - Use connection pooling for Qdrant
   - Implement caching for frequent queries
   - Add rate limiting
   - Use async/await throughout

2. **Frontend Optimization:**
   - Enable gzip compression
   - Implement service worker for caching
   - Optimize images and assets
   - Use CDN for static content

### Monitoring and Logging

1. **Backend Monitoring:**
   - Add structured logging
   - Implement health checks
   - Monitor API response times
   - Track error rates

2. **User Analytics:**
   - Track consultation completion rates
   - Monitor doctor recommendation accuracy
   - Analyze common user queries

### Security Considerations

1. **API Security:**
   - Implement API rate limiting
   - Add input validation and sanitization
   - Use HTTPS only
   - Secure API keys and environment variables

2. **Data Privacy:**
   - Implement data retention policies
   - Add user consent mechanisms
   - Ensure HIPAA compliance if needed
   - Regular security audits

### Backup and Recovery

1. **Vector Database Backup:**
   - Regular Qdrant snapshots
   - Backup embedding collections
   - Test restore procedures

2. **Configuration Backup:**
   - Version control all configurations
   - Backup environment variables securely
   - Document deployment procedures

## 🔧 Troubleshooting Common Issues

### API Issues

1. **500 Internal Server Error**
   - Check API keys are valid
   - Verify Qdrant connection
   - Check server logs for details

2. **CORS Errors**
   - Verify ALLOWED_ORIGINS in .env
   - Check frontend URL matches

3. **Slow Response Times**
   - Check Qdrant query performance
   - Monitor Gemini API rate limits
   - Optimize embedding queries

### Frontend Issues

1. **Build Errors**
   - Check Node.js version (16+)
   - Clear npm cache: `npm cache clean --force`
   - Delete node_modules and reinstall

2. **API Connection Issues**
   - Verify backend is running
   - Check network connectivity
   - Confirm API endpoints are correct

### Performance Issues

1. **High Memory Usage**
   - Monitor Qdrant memory usage
   - Optimize vector collection size
   - Use batch processing for embeddings

2. **Slow Question Generation**
   - Check Gemini API latency
   - Implement request caching
   - Optimize prompt engineering

---

## 📞 Support

For deployment issues or questions:
1. Check the logs first
2. Verify all environment variables
3. Test with mock data
4. Contact support with error details

The system is now ready for production deployment! 🎉
