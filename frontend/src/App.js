import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

const App = () => {
  const [step, setStep] = useState('initial'); // 'initial', 'iterative', 'results'
  const [initialCondition, setInitialCondition] = useState('');
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);
  
  // Smart iterative workflow states
  const [sessionId, setSessionId] = useState(null);
  const [currentQuestion, setCurrentQuestion] = useState(null);
  const [conversationHistory, setConversationHistory] = useState([]);
  const [confidenceScore, setConfidenceScore] = useState(null);
  const [currentAnswer, setCurrentAnswer] = useState('');
  const [currentCustomAnswer, setCurrentCustomAnswer] = useState('');

  // API base URL
  const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

  // Start smart iterative session
  const startIterativeSession = async (e) => {
    e.preventDefault();
    if (!initialCondition.trim()) {
      setError('Please describe your eye condition');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_BASE_URL}/api/iterative/start`, {
        condition: initialCondition
      });

      setSessionId(response.data.session_id);
      setCurrentQuestion(response.data.first_question);
      setConfidenceScore(response.data.confidence_score);
      setConversationHistory([]);
      setStep('iterative');
    } catch (err) {
      setError(`Failed to start session: ${err.response?.data?.detail || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleIterativeAnswer = async () => {
    if (!currentAnswer.trim() && !currentCustomAnswer.trim()) {
      setError('Please provide an answer');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const answerText = currentAnswer === 'Other' ? currentCustomAnswer : currentAnswer;
      
      const response = await axios.post(`${API_BASE_URL}/api/iterative/next`, {
        session_id: sessionId,
        answer: answerText
      });

      // Update conversation history
      setConversationHistory(response.data.conversation_history);
      setConfidenceScore(response.data.confidence_score);

      if (response.data.is_complete) {
        // Session is complete, show results
        setResults({
          doctor: response.data.doctor_recommendation,
          summary_for_doctor: response.data.summary_for_doctor
        });
        setStep('results');
      } else {
        // Continue with next question
        setCurrentQuestion(response.data.question);
        setCurrentAnswer('');
        setCurrentCustomAnswer('');
      }
    } catch (err) {
      setError(`Failed to process answer: ${err.response?.data?.detail || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setStep('initial');
    setInitialCondition('');
    setResults(null);
    setError(null);
    
    // Reset iterative states
    setSessionId(null);
    setCurrentQuestion(null);
    setConversationHistory([]);
    setConfidenceScore(null);
    setCurrentAnswer('');
    setCurrentCustomAnswer('');
  };

  const renderInitialForm = () => (
    <div className="form-container">
      <h1>Smart Ophthalmology Assistant</h1>
      <p className="subtitle">
        Describe your eye-related symptoms and I'll ask targeted questions to help find the right specialist.
      </p>
      
      <form onSubmit={startIterativeSession}>
        <div className="form-group">
          <label htmlFor="condition">
            What eye condition or symptoms are you experiencing?
          </label>
          <textarea
            id="condition"
            value={initialCondition}
            onChange={(e) => setInitialCondition(e.target.value)}
            placeholder="e.g., I've been having blurry vision and headaches for the past week..."
            rows={4}
            disabled={loading}
          />
        </div>
        
        <button type="submit" disabled={loading || !initialCondition.trim()}>
          {loading ? 'Starting Smart Consultation...' : 'Start Smart Consultation'}
        </button>
      </form>
    </div>
  );

  const renderIterativeQuestion = () => (
    <div className="form-container">
      <h2>Smart Consultation</h2>
      
      {/* Confidence Score Display */}
      {confidenceScore && (
        <div className="confidence-panel">
          <h4>AI Diagnostic Confidence</h4>
          <div className="confidence-bar">
            <div 
              className="confidence-fill" 
              style={{ width: `${(confidenceScore.overall_confidence * 100)}%` }}
            ></div>
          </div>
          <p>{Math.round(confidenceScore.overall_confidence * 100)}% confident in recommendation</p>
          <div className="leading-doctor">
            <small>Current leading recommendation: <strong>{confidenceScore.doctor_confidence ? 
              Object.entries(confidenceScore.doctor_confidence)
                .sort(([,a], [,b]) => b - a)[0][0] : 'Calculating...'
            }</strong></small>
          </div>
        </div>
      )}
      
      {/* Conversation History */}
      {conversationHistory.length > 0 && (
        <div className="conversation-history">
          <h4>Previous Questions</h4>
          <div className="history-list">
            {conversationHistory.map((entry, index) => (
              <div key={index} className="history-entry">
                <div className="history-question">Q{index + 1}: {entry.question}</div>
                <div className="history-answer">A{index + 1}: {entry.answer}</div>
              </div>
            ))}
          </div>
        </div>
      )}
      
      {/* Current Question */}
      {currentQuestion && (
        <div className="current-question">
          <h3 className="question-title">
            Question {conversationHistory.length + 1}: {currentQuestion.question}
          </h3>
          
          <div className="options-group">
            {currentQuestion.options.map((option, index) => (
              <div key={index}>
                <label className="option-label">
                  <input
                    type="radio"
                    name="current_answer"
                    value={option.text}
                    checked={currentAnswer === option.text}
                    onChange={(e) => {
                      setCurrentAnswer(e.target.value);
                      if (!option.is_other) {
                        setCurrentCustomAnswer('');
                      }
                    }}
                    disabled={loading}
                  />
                  
                  <span className="option-text">{option.text}</span>
                </label>
                
                {option.is_other && currentAnswer === option.text && (
                  <div className="custom-input-container">
                    <textarea
                      placeholder="Please specify..."
                      value={currentCustomAnswer}
                      onChange={(e) => setCurrentCustomAnswer(e.target.value)}
                      rows={2}
                      disabled={loading}
                    />
                  </div>
                )}
              </div>
            ))}
          </div>
          
          <div className="button-group">
            <button 
              type="button" 
              onClick={resetForm} 
              disabled={loading}
              className="secondary-button"
            >
              Start Over
            </button>
            <button 
              onClick={handleIterativeAnswer} 
              disabled={loading || (!currentAnswer.trim() && !currentCustomAnswer.trim())}
              className="primary-button"
            >
              {loading ? 'Processing...' : 'Submit Answer'}
            </button>
          </div>
        </div>
      )}
    </div>
  );

  const renderResults = () => (
    <div className="results-container">
      <h2>Specialist Recommendation</h2>
      
      <div className="doctor-recommendation">
        <h3>Recommended Specialist</h3>
        <div className="doctor-card">
          <div className="doctor-type">
            {results.doctor.doctor_type}
          </div>
          <div className="doctor-reasoning">
            <strong>Why this specialist:</strong>
            <p>{results.doctor.reasoning}</p>
          </div>
        </div>
      </div>
      
      <div className="medical-summary">
        <h3>Summary for Your Doctor</h3>
        <div className="summary-content">
          {results.summary_for_doctor.split('\n').map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>
      </div>
      
      <div className="button-group">
        <button onClick={resetForm} className="primary-button">
          New Consultation
        </button>
        <button 
          onClick={() => window.print()} 
          className="secondary-button"
        >
          Print Summary
        </button>
      </div>
    </div>
  );

  return (
    <div className="app">
      <div className="container">
        {error && (
          <div className="error-message">
            <strong>Error:</strong> {error}
            <button 
              className="error-close" 
              onClick={() => setError(null)}
            >
              ×
            </button>
          </div>
        )}
        
        {step === 'initial' && renderInitialForm()}
        {step === 'iterative' && renderIterativeQuestion()}
        {step === 'results' && renderResults()}
      </div>
      
      <footer className="footer">
        <p>
          This tool provides suggestions only. Always consult with a healthcare professional 
          for proper diagnosis and treatment.
        </p>
      </footer>
    </div>
  );
};

export default App;
