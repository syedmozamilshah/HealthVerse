using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

// M-2 USED IN USERCONTROLLER FOR PATIENT PROFILE MANAGEMENT

namespace first_api.Entities.PatientModel
{
    public class UpdateProfileDtos
    {
        public string FirstName { get; set; } = string.Empty;

        public string LastName { get; set; } = string.Empty;

        public string Address { get; set; } = string.Empty;

        public string WhatsappNo { get; set; } = string.Empty;

        public IFormFile? ProfileImage { get; set; }
    }
}