import React, { useState } from 'react';
import axios from 'axios';
import './App.css';

const App = () => {
  const [step, setStep] = useState('initial'); // 'initial', 'questions', 'results'
  const [initialCondition, setInitialCondition] = useState('');
  const [questions, setQuestions] = useState([]);
  const [answers, setAnswers] = useState([]);
  const [customAnswers, setCustomAnswers] = useState({});
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState(null);
  const [error, setError] = useState(null);

  // API base URL
  const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

  const handleInitialSubmit = async (e) => {
    e.preventDefault();
    if (!initialCondition.trim()) {
      setError('Please describe your eye condition');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_BASE_URL}/api/generate-questions`, {
        condition: initialCondition
      });

      setQuestions(response.data.questions);
      setAnswers(new Array(response.data.questions.length).fill(null));
      setStep('questions');
    } catch (err) {
      setError(`Failed to generate questions: ${err.response?.data?.detail || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (questionIndex, selectedOption) => {
    const newAnswers = [...answers];
    newAnswers[questionIndex] = {
      question_index: questionIndex,
      selected_option: selectedOption,
      custom_answer: null
    };
    setAnswers(newAnswers);

    // Clear custom answer if not "Other"
    const question = questions[questionIndex];
    const selectedOptionObj = question.options.find(opt => opt.text === selectedOption);
    if (!selectedOptionObj?.is_other) {
      const newCustomAnswers = { ...customAnswers };
      delete newCustomAnswers[questionIndex];
      setCustomAnswers(newCustomAnswers);
    }
  };

  const handleCustomAnswerChange = (questionIndex, customAnswer) => {
    const newCustomAnswers = { ...customAnswers };
    newCustomAnswers[questionIndex] = customAnswer;
    setCustomAnswers(newCustomAnswers);

    // Update the answer with custom response but keep selected_option for "Other"
    const newAnswers = [...answers];
    if (newAnswers[questionIndex]) {
      newAnswers[questionIndex] = {
        ...newAnswers[questionIndex],
        custom_answer: customAnswer
      };
      setAnswers(newAnswers);
    }
  };

  const handleQuestionsSubmit = async (e) => {
    e.preventDefault();
    
    // Validate all questions are answered
    const unansweredQuestions = [];
    for (let i = 0; i < questions.length; i++) {
      const answer = answers[i];
      if (!answer || (!answer.selected_option && !answer.custom_answer)) {
        unansweredQuestions.push(i + 1);
      }
    }

    if (unansweredQuestions.length > 0) {
      setError(`Please answer question(s): ${unansweredQuestions.join(', ')}`);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Prepare answers for API
      const formattedAnswers = answers.map((answer, index) => ({
        question_index: index,
        selected_option: answer.selected_option,
        custom_answer: customAnswers[index] || answer.custom_answer
      }));

      const response = await axios.post(`${API_BASE_URL}/api/process-answers`, {
        initial_condition: initialCondition,
        answers: formattedAnswers
      });

      setResults(response.data);
      setStep('results');
    } catch (err) {
      setError(`Failed to process answers: ${err.response?.data?.detail || err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setStep('initial');
    setInitialCondition('');
    setQuestions([]);
    setAnswers([]);
    setCustomAnswers({});
    setResults(null);
    setError(null);
  };

  const renderInitialForm = () => (
    <div className="form-container">
      <h1>Ophthalmology Assistant</h1>
      <p className="subtitle">
        Describe your eye-related symptoms or concerns, and I'll help you find the right specialist.
      </p>
      
      <form onSubmit={handleInitialSubmit}>
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
          {loading ? 'Generating Questions...' : 'Continue'}
        </button>
      </form>
    </div>
  );

  const renderQuestions = () => (
    <div className="form-container">
      <h2>Follow-up Questions</h2>
      <p className="subtitle">
        Please answer these questions to help us recommend the most appropriate specialist.
      </p>
      
      <form onSubmit={handleQuestionsSubmit}>
        {questions.map((question, questionIndex) => (
          <div key={questionIndex} className="question-group">
            <h3 className="question-title">
              {questionIndex + 1}. {question.question}
            </h3>
            
            <div className="options-group">
              {question.options.map((option, optionIndex) => (
                <div key={optionIndex}>
                  <label className="option-label">
                    <input
                      type="radio"
                      name={`question_${questionIndex}`}
                      value={option.text}
                      checked={answers[questionIndex]?.selected_option === option.text}
                      onChange={(e) => handleAnswerChange(questionIndex, e.target.value)}
                      disabled={loading}
                    />
                    <span className="option-text">{option.text}</span>
                  </label>
                  
                  {option.is_other && answers[questionIndex]?.selected_option === option.text && (
                    <div className="custom-input-container">
                      <textarea
                        placeholder="Please specify..."
                        value={customAnswers[questionIndex] || ''}
                        onChange={(e) => handleCustomAnswerChange(questionIndex, e.target.value)}
                        rows={2}
                        disabled={loading}
                      />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        ))}
        
        <div className="button-group">
          <button type="button" onClick={resetForm} disabled={loading}>
            Start Over
          </button>
          <button type="submit" disabled={loading}>
            {loading ? 'Processing...' : 'Get Recommendation'}
          </button>
        </div>
      </form>
    </div>
  );

  const renderResults = () => (
    <div className="results-container">
      <h2>Recommendation</h2>
      
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
        {step === 'questions' && renderQuestions()}
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
