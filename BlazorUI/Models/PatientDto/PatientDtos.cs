using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace BlazorUI.Models.PatientDto
{
    public class PatientDtos
    {

        public string Id { get; set; } = string.Empty;


        public string History { get; set; } = string.Empty;


        public string InitialConditions { get; set; } = string.Empty;


        public string FirstName { get; set; } = string.Empty;


        public string LastName { get; set; } = string.Empty;


        public string Gender { get; set; } = string.Empty;


        public string BloodGroup { get; set; } = string.Empty;

    }

    public class PatientDtoResponse
    {
        public bool IsSuccess { get; set; } = true;
        public string Message { get; set; } = string.Empty;
        public PatientDtos? Data { get; set; }
    }

}