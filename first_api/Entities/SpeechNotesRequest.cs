using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

// M-4 USED IN SpeechNotesController.cs
namespace first_api.Entities
{
    public class SpeechNotesRequest
    {
        public string ApiKey { get; set; } = "";
        public string ApiSecret { get; set; } = "";
        public string Type { get; set; } = "upload";
        public string FileUrl { get; set; } = "";
        public string FileName { get; set; } = "";
        public string Language { get; set; } = "en-US";
        public string NumSpeakers { get; set; } = "1";
        public string? Api_Custom { get; set; }
        public string? FromSeconds { get; set; }
        public string? ToSeconds { get; set; }
    }
    
    public class VoiceTranscribeRequest
{
    public string FileUrl { get; set; } = "";
    public string FileName { get; set; } = "";
}
}