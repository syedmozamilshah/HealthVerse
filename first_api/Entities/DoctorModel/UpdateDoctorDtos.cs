using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;


// M-2 USED IN DOCTORCONTROLLER FOR UPDATING OF DOCTOR PROFILE MANAGEMENT
namespace first_api.Entities.DoctorModel
{
    public class UpdateDoctorDtos
    {
        [JsonPropertyName("licence_number")]
        public string LicenceNumber { get; set; } = string.Empty;

        [JsonPropertyName("speciality")]
        public string Speciality { get; set; } = string.Empty;

        [JsonPropertyName("experience")]
        public string Experience { get; set; } = string.Empty;

        [JsonPropertyName("fee")]
        public string Fee { get; set; } = string.Empty; 
        [JsonPropertyName("image_url")]

        [FromForm(Name = "image_url")]
        public IFormFile? ImageUrl { get; set; }

        [JsonPropertyName("specialization")]
        public string Specialization { get; set; } = string.Empty;


        [JsonPropertyName("is_available")]
        public bool IsAvailable { get; set; }

        [JsonPropertyName("clinic_info")]
        public ClinicInfo ClinicInfo { get; set; } = new();

        [JsonPropertyName("available_time_morning")]
        public AvailableTime AvailableTimeMorning { get; set; } = new();


        [JsonPropertyName("daily_availabilities")]
        public List<DayAvailability> DailyAvailabilities { get; set; } = new();
        
        [JsonPropertyName("renewal_date")]
        public DateTime RenewalDate { get; set; }
        
    }
}