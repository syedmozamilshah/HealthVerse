#!/usr/bin/env python3
"""
Frontend-Backend Integration Test
==================================

Tests the complete integration between React frontend and FastAPI backend
by automating browser interactions and verifying the entire user workflow.
"""

import time
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, WebDriverException

# Test configuration
FRONTEND_URL = "http://localhost:3000"
BACKEND_URL = "http://localhost:8000"

class FrontendIntegrationTest:
    """Test frontend-backend integration via browser automation"""
    
    def __init__(self):
        self.driver = None
        self.wait = None
    
    def setup_driver(self):
        """Setup Chrome driver with appropriate options"""
        try:
            chrome_options = Options()
            chrome_options.add_argument("--no-sandbox")
            chrome_options.add_argument("--disable-dev-shm-usage")
            chrome_options.add_argument("--disable-gpu")
            chrome_options.add_argument("--window-size=1920,1080")
            # Remove headless for debugging - uncomment next line to run headless
            # chrome_options.add_argument("--headless")
            
            print("🔧 Setting up Chrome WebDriver...")
            self.driver = webdriver.Chrome(options=chrome_options)
            self.wait = WebDriverWait(self.driver, 10)
            print("✅ Chrome WebDriver setup complete")
            return True
            
        except WebDriverException as e:
            print(f"❌ WebDriver setup failed: {str(e)}")
            print("💡 Make sure Chrome and ChromeDriver are installed")
            return False
    
    def test_services_running(self):
        """Test that both frontend and backend services are accessible"""
        print("\n🔍 Testing service availability...")
        
        # Test backend
        try:
            response = requests.get(f"{BACKEND_URL}/health", timeout=5)
            if response.status_code == 200:
                print("✅ Backend service is running")
            else:
                print(f"❌ Backend returned status {response.status_code}")
                return False
        except requests.RequestException as e:
            print(f"❌ Backend not accessible: {str(e)}")
            return False
        
        # Test frontend
        try:
            response = requests.get(FRONTEND_URL, timeout=5)
            if response.status_code == 200:
                print("✅ Frontend service is running")
                return True
            else:
                print(f"❌ Frontend returned status {response.status_code}")
                return False
        except requests.RequestException as e:
            print(f"❌ Frontend not accessible: {str(e)}")
            return False
    
    def test_initial_page_load(self):
        """Test that the initial page loads correctly"""
        print("\n🔍 Testing initial page load...")
        
        try:
            self.driver.get(FRONTEND_URL)
            
            # Wait for the main heading to appear
            heading = self.wait.until(
                EC.presence_of_element_located((By.TAG_NAME, "h1"))
            )
            
            if "Smart Ophthalmology Assistant" in heading.text:
                print("✅ Initial page loaded successfully")
                print(f"   Page title: {heading.text}")
                return True
            else:
                print(f"❌ Unexpected heading: {heading.text}")
                return False
                
        except TimeoutException:
            print("❌ Initial page failed to load within timeout")
            return False
    
    def test_condition_input_and_session_start(self):
        """Test entering a condition and starting the iterative session"""
        print("\n🔍 Testing condition input and session start...")
        
        try:
            # Find the condition textarea
            condition_textarea = self.wait.until(
                EC.presence_of_element_located((By.ID, "condition"))
            )
            
            # Enter a test condition
            test_condition = "I have sudden onset of flashing lights and floaters in my right eye"
            condition_textarea.clear()
            condition_textarea.send_keys(test_condition)
            print(f"✅ Entered condition: {test_condition}")
            
            # Find and click the submit button
            submit_button = self.driver.find_element(By.XPATH, "//button[@type='submit']")
            submit_button.click()
            print("✅ Clicked submit button")
            
            # Wait for the iterative session to start (look for confidence panel)
            confidence_panel = self.wait.until(
                EC.presence_of_element_located((By.CLASS_NAME, "confidence-panel"))
            )
            print("✅ Iterative session started - confidence panel visible")
            
            # Check if a question is displayed
            question_element = self.wait.until(
                EC.presence_of_element_located((By.CLASS_NAME, "question-title"))
            )
            print(f"✅ First question displayed: {question_element.text[:80]}...")
            
            return True
            
        except TimeoutException as e:
            print(f"❌ Session start failed: {str(e)}")
            return False
    
    def test_answer_submission_and_flow(self):
        """Test answering questions and following the iterative flow"""
        print("\n🔍 Testing answer submission and iterative flow...")
        
        try:
            max_questions = 5
            question_count = 0
            
            while question_count < max_questions:
                question_count += 1
                print(f"   Processing question {question_count}...")
                
                # Find available options
                options = self.driver.find_elements(By.XPATH, "//input[@type='radio'][@name='current_answer']")
                
                if not options:
                    print("❌ No answer options found")
                    return False
                
                # Select the first non-other option
                selected_option = None
                for option in options:
                    option_text = option.get_attribute("value")
                    if option_text.lower() != "other":
                        option.click()
                        selected_option = option_text
                        print(f"   Selected option: {option_text}")
                        break
                
                if not selected_option:
                    print("❌ No suitable option found")
                    return False
                
                # Click submit answer button
                submit_button = self.wait.until(
                    EC.element_to_be_clickable((By.CLASS_NAME, "primary-button"))
                )
                submit_button.click()
                print("   Submitted answer")
                
                # Wait a moment for processing
                time.sleep(2)
                
                # Check if we've reached the results page
                try:
                    results_container = self.driver.find_element(By.CLASS_NAME, "results-container")
                    print("✅ Reached results page!")
                    return self.test_results_display()
                except:
                    # Still in iterative flow, continue
                    try:
                        # Wait for next question or processing to complete
                        self.wait.until(
                            EC.presence_of_element_located((By.CLASS_NAME, "question-title"))
                        )
                        print("   Next question loaded")
                    except TimeoutException:
                        # Might have completed without showing results immediately
                        time.sleep(1)
                        continue
            
            print("❌ Maximum questions reached without completion")
            return False
            
        except Exception as e:
            print(f"❌ Answer submission failed: {str(e)}")
            return False
    
    def test_results_display(self):
        """Test that results are displayed correctly"""
        print("\n🔍 Testing results display...")
        
        try:
            # Check for doctor recommendation
            doctor_type_element = self.wait.until(
                EC.presence_of_element_located((By.CLASS_NAME, "doctor-type"))
            )
            doctor_type = doctor_type_element.text
            print(f"✅ Doctor recommendation displayed: {doctor_type}")
            
            # Check for reasoning
            reasoning_element = self.driver.find_element(By.CLASS_NAME, "doctor-reasoning")
            print("✅ Doctor reasoning displayed")
            
            # Check for medical summary
            summary_element = self.driver.find_element(By.CLASS_NAME, "summary-content")
            print("✅ Medical summary displayed")
            
            # Verify valid doctor types
            valid_doctors = ["Ophthalmologist", "Optometrist", "Optician", "Ocular Surgeon"]
            if doctor_type in valid_doctors:
                print(f"✅ Valid doctor type recommended: {doctor_type}")
                return True
            else:
                print(f"❌ Invalid doctor type: {doctor_type}")
                return False
            
        except TimeoutException:
            print("❌ Results display failed")
            return False
    
    def test_new_consultation_flow(self):
        """Test starting a new consultation"""
        print("\n🔍 Testing new consultation flow...")
        
        try:
            # Click "New Consultation" button
            new_consultation_button = self.wait.until(
                EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'New Consultation')]"))
            )
            new_consultation_button.click()
            print("✅ Clicked New Consultation button")
            
            # Wait for initial form to appear
            condition_textarea = self.wait.until(
                EC.presence_of_element_located((By.ID, "condition"))
            )
            print("✅ Returned to initial form")
            
            # Verify form is reset
            if condition_textarea.get_attribute("value") == "":
                print("✅ Form properly reset")
                return True
            else:
                print("❌ Form not properly reset")
                return False
            
        except TimeoutException:
            print("❌ New consultation flow failed")
            return False
    
    def run_complete_test(self):
        """Run the complete frontend integration test suite"""
        print("🧪 Starting Frontend-Backend Integration Test")
        print("=" * 60)
        
        # Check services first
        if not self.test_services_running():
            return False
        
        # Setup browser
        if not self.setup_driver():
            return False
        
        try:
            tests = [
                ("Initial Page Load", self.test_initial_page_load),
                ("Condition Input & Session Start", self.test_condition_input_and_session_start),
                ("Answer Submission & Flow", self.test_answer_submission_and_flow),
                ("New Consultation Flow", self.test_new_consultation_flow),
            ]
            
            passed = 0
            failed = 0
            
            for test_name, test_method in tests:
                try:
                    if test_method():
                        print(f"✅ {test_name}: PASSED")
                        passed += 1
                    else:
                        print(f"❌ {test_name}: FAILED")
                        failed += 1
                except Exception as e:
                    print(f"❌ {test_name}: FAILED - {str(e)}")
                    failed += 1
            
            print("\n" + "=" * 60)
            print(f"🏁 Frontend Integration Tests Complete")
            print(f"✅ Passed: {passed}")
            print(f"❌ Failed: {failed}")
            print(f"📊 Success Rate: {(passed / (passed + failed)) * 100:.1f}%")
            
            if failed == 0:
                print("🎉 All frontend integration tests passed!")
                print("🔗 Frontend and backend are properly integrated!")
                return True
            else:
                print("⚠️  Some frontend tests failed.")
                return False
                
        finally:
            if self.driver:
                print("\n🔧 Closing browser...")
                self.driver.quit()

def main():
    """Main test execution"""
    test_runner = FrontendIntegrationTest()
    success = test_runner.run_complete_test()
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
