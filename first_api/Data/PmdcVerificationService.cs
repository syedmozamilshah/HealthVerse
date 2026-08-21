using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;


// M-1 PMDC API integration for doctor verification in DoctorVerificationController
namespace first_api.Data
{
    public class PmdcVerificationService
    {
        private readonly HttpClient _httpClient;
        private const string PMDC_API_URL = "https://hospitals-inspections.pmdc.pk/api/DRC/GetData";

        public PmdcVerificationService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<PmdcVerificationResult> VerifyDoctorAsync(string registrationNo, string? name = null, string? fatherName = null)
        {
            var result = new PmdcVerificationResult();

            try
            {
                if (string.IsNullOrWhiteSpace(registrationNo))
                {
                    result.IsVerified = false;
                    result.Message = "Registration number is required";
                    return result;
                }

                // Build form data
                var formData = new Dictionary<string, string>
                {
                    { "RegistrationNo", registrationNo },
                    { "Name", name ?? "" },
                    { "FatherName", fatherName ?? "" }
                };

                var content = new FormUrlEncodedContent(formData);

                // Set headers
                _httpClient.DefaultRequestHeaders.Clear();
                _httpClient.DefaultRequestHeaders.Add("Accept", "application/json, text/javascript, */*; q=0.01");
                _httpClient.DefaultRequestHeaders.Add("Origin", "https://pmdc.pk");
                _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0");

                var response = await _httpClient.PostAsync(PMDC_API_URL, content);
                
                var responseContent = await response.Content.ReadAsStringAsync();

                Console.WriteLine($"PMDC API Response for {registrationNo}: {responseContent}");

                if (!response.IsSuccessStatusCode)
                {
                    result.IsVerified = false;
                    result.Message = $"PMDC API returned status code: {response.StatusCode}";
                    result.RawResponse = responseContent;
                    return result;
                }

                // Try to parse the response - handle different response formats
                result.RawResponse = responseContent;
                
                // Check if response is empty or just whitespace
                if (string.IsNullOrWhiteSpace(responseContent) || responseContent == "[]" || responseContent == "{}")
                {
                    result.IsVerified = false;
                    result.Message = "Doctor not found in PMDC records";
                    return result;
                }

                try
                {
                    // First try parsing as an array
                    if (responseContent.TrimStart().StartsWith("["))
                    {
                        var pmdcList = JsonSerializer.Deserialize<List<PmdcDoctorRecord>>(responseContent, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });

                        if (pmdcList != null && pmdcList.Count > 0)
                        {
                            var doctor = pmdcList[0];
                            result.IsVerified = true;
                            result.Message = "Doctor found in PMDC records";
                            result.DoctorName = doctor.Name;
                            result.FatherName = doctor.FatherName;
                            result.RegistrationNo = doctor.RegistrationNo;
                            result.Qualification = doctor.Qualification;
                            result.Status = doctor.Status;
                            result.DateOfRegistration = doctor.DateOfRegistration;
                        }
                        else
                        {
                            result.IsVerified = false;
                            result.Message = "Doctor not found in PMDC records";
                        }
                    }
                    // Try parsing as a single object
                    else if (responseContent.TrimStart().StartsWith("{"))
                    {
                        // Try parsing as wrapper object with data array
                        var wrapperResponse = JsonSerializer.Deserialize<PmdcApiResponse>(responseContent, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });

                        if (wrapperResponse?.Data != null && wrapperResponse.Data.Count > 0)
                        {
                            var doctor = wrapperResponse.Data[0];
                            result.IsVerified = true;
                            result.Message = "Doctor found in PMDC records";
                            result.DoctorName = doctor.Name;
                            result.FatherName = doctor.FatherName;
                            result.RegistrationNo = doctor.RegistrationNo;
                            result.Qualification = doctor.Qualification;
                            result.Status = doctor.Status;
                            result.DateOfRegistration = doctor.DateOfRegistration;
                        }
                        else
                        {
                            // Try as single doctor record
                            var singleDoctor = JsonSerializer.Deserialize<PmdcDoctorRecord>(responseContent, new JsonSerializerOptions
                            {
                                PropertyNameCaseInsensitive = true
                            });

                            if (singleDoctor != null && !string.IsNullOrEmpty(singleDoctor.Name))
                            {
                                result.IsVerified = true;
                                result.Message = "Doctor found in PMDC records";
                                result.DoctorName = singleDoctor.Name;
                                result.FatherName = singleDoctor.FatherName;
                                result.RegistrationNo = singleDoctor.RegistrationNo;
                                result.Qualification = singleDoctor.Qualification;
                                result.Status = singleDoctor.Status;
                                result.DateOfRegistration = singleDoctor.DateOfRegistration;
                            }
                            else
                            {
                                result.IsVerified = false;
                                result.Message = "Doctor not found in PMDC records";
                            }
                        }
                    }
                    else
                    {
                        result.IsVerified = false;
                        result.Message = "Unexpected PMDC response format";
                    }
                }
                catch (JsonException parseEx)
                {
                    Console.WriteLine($"PMDC JSON Parse Error: {parseEx.Message}");
                    result.IsVerified = false;
                    result.Message = "Could not parse PMDC response - manual verification required";
                }
            }
            catch (HttpRequestException ex)
            {
                result.IsVerified = false;
                result.Message = $"Network error connecting to PMDC: {ex.Message}";
                Console.WriteLine($"PMDC API Network Error: {ex.Message}");
            }
            catch (JsonException ex)
            {
                result.IsVerified = false;
                result.Message = $"Error parsing PMDC response: {ex.Message}";
                Console.WriteLine($"PMDC API JSON Error: {ex.Message}");
            }
            catch (Exception ex)
            {
                result.IsVerified = false;
                result.Message = $"Error verifying with PMDC: {ex.Message}";
                Console.WriteLine($"PMDC API Error: {ex.Message}");
            }

            return result;
        }
    }


    public class PmdcVerificationResult
    {
        public bool IsVerified { get; set; }
        public string Message { get; set; } = string.Empty;
        public string? DoctorName { get; set; }
        public string? FatherName { get; set; }
        public string? RegistrationNo { get; set; }
        public string? Qualification { get; set; }
        public string? Status { get; set; }
        public string? DateOfRegistration { get; set; }
        public string? RawResponse { get; set; }
    }

    public class PmdcDoctorRecord
    {
        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("fatherName")]
        public string? FatherName { get; set; }

        [JsonPropertyName("registrationNo")]
        public string? RegistrationNo { get; set; }

        [JsonPropertyName("qualification")]
        public string? Qualification { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("registrationType")]
        public string? RegistrationType { get; set; }

        [JsonPropertyName("dateOfRegistration")]
        public string? DateOfRegistration { get; set; }
    }

    public class PmdcApiResponse
    {
        [JsonPropertyName("data")]
        public List<PmdcDoctorRecord>? Data { get; set; }

        [JsonPropertyName("success")]
        public bool? Success { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }
}
