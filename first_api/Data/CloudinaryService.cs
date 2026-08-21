using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using first_api.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

// M-1 USED IN DOCTOR VERIFICATION CONTROLLER FOR UPLOADING DOCUMENTS TO CLOUDINARY
// M-2 FOR PROFILE MANAGEMENT
// M-5 USED IN PRESCRIPTION CONTROLLER TO UPLOAD PRESCRIPTION IMAGES AND PDFS TO CLOUDINARY
namespace first_api.Data
{
    public class CloudinaryService
    {
        private readonly Cloudinary _cloudinary;
        public CloudinaryService(IOptions<CloudinarySettings> config)
        {
            var account = new Account(
                config.Value.CloudName,
                config.Value.ApiKey,
                config.Value.ApiSecret
            );
            _cloudinary = new Cloudinary(account);
        }
        public async Task<string?> UploadImageAsync(IFormFile file)
        {
            try 
            {
                if (file == null || file.Length == 0) 
                {
                    Console.WriteLine("CloudinaryService: File is null or empty");
                    return null;
                }

                Console.WriteLine($"CloudinaryService: Uploading file {file.FileName}, Size: {file.Length}");

                using var stream = file.OpenReadStream();
                var uploadParams = new ImageUploadParams
                {
                    File = new FileDescription(file.FileName, stream),
                    Folder = "user_profiles" 
                };

                var uploadResult = await _cloudinary.UploadAsync(uploadParams);
                
                if (uploadResult.Error != null)
                {
                    Console.WriteLine($"Cloudinary Error: {uploadResult.Error.Message}");
                    throw new Exception($"Cloudinary Error: {uploadResult.Error.Message}");
                }

                Console.WriteLine($"Cloudinary Success: {uploadResult.SecureUrl}");
                return uploadResult?.SecureUrl?.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Cloudinary Exception: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Upload a base64 encoded image to Cloudinary
        /// </summary>
        public async Task<string?> UploadBase64ImageAsync(string base64Image, string folder = "prescriptions", string? publicId = null)
        {
            try 
            {
                if (string.IsNullOrEmpty(base64Image)) 
                {
                    Console.WriteLine("CloudinaryService: Base64 image is null or empty");
                    return null;
                }

                // Remove data URL prefix if present (e.g., "data:image/png;base64," or "data:image/jpeg;base64,")
                var base64Data = base64Image;
                var mimeType = "image/png"; // Default
                
                if (base64Image.Contains(","))
                {
                    // Extract MIME type from data URL
                    var prefix = base64Image.Split(',')[0];
                    if (prefix.Contains("image/jpeg"))
                    {
                        mimeType = "image/jpeg";
                    }
                    else if (prefix.Contains("image/png"))
                    {
                        mimeType = "image/png";
                    }
                    base64Data = base64Image.Split(',')[1];
                }

                Console.WriteLine($"CloudinaryService: Uploading base64 image ({mimeType}) to folder: {folder}, data length: {base64Data.Length}");

                var uploadParams = new ImageUploadParams
                {
                    File = new FileDescription($"data:{mimeType};base64,{base64Data}"),
                    Folder = folder,
                    PublicId = publicId,
                    Overwrite = true
                };

                var uploadResult = await _cloudinary.UploadAsync(uploadParams);
                
                if (uploadResult.Error != null)
                {
                    Console.WriteLine($"Cloudinary Error: {uploadResult.Error.Message}");
                    throw new Exception($"Cloudinary Error: {uploadResult.Error.Message}");
                }

                Console.WriteLine($"Cloudinary Success: {uploadResult.SecureUrl}");
                return uploadResult?.SecureUrl?.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Cloudinary Exception: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Upload a base64 encoded PDF to Cloudinary
        /// </summary>
        public async Task<string?> UploadBase64PdfAsync(string base64Pdf, string folder = "prescriptions", string? publicId = null)
        {
            try 
            {
                if (string.IsNullOrEmpty(base64Pdf)) 
                {
                    Console.WriteLine("CloudinaryService: Base64 PDF is null or empty");
                    return null;
                }

                // Remove data URL prefix if present (e.g., "data:application/pdf;base64,")
                var base64Data = base64Pdf;
                if (base64Pdf.Contains(","))
                {
                    base64Data = base64Pdf.Split(',')[1];
                }

                Console.WriteLine($"CloudinaryService: Uploading base64 PDF to folder: {folder}");

                // Convert base64 to byte array
                var pdfBytes = Convert.FromBase64String(base64Data);
                using var stream = new MemoryStream(pdfBytes);

                // Use RawUploadParams for PDF files
                var uploadParams = new RawUploadParams
                {
                    File = new FileDescription(publicId ?? $"prescription_{DateTime.Now:yyyyMMddHHmmss}.pdf", stream),
                    Folder = folder,
                    PublicId = publicId,
                    Overwrite = true
                };

                var uploadResult = await _cloudinary.UploadAsync(uploadParams);
                
                if (uploadResult.Error != null)
                {
                    Console.WriteLine($"Cloudinary PDF Error: {uploadResult.Error.Message}");
                    throw new Exception($"Cloudinary PDF Error: {uploadResult.Error.Message}");
                }

                Console.WriteLine($"Cloudinary PDF Success: {uploadResult.SecureUrl}");
                return uploadResult?.SecureUrl?.ToString();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Cloudinary PDF Exception: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Upload a base64 encoded file (image or PDF) to Cloudinary
        /// Automatically detects the file type from the data URL prefix
        /// </summary>
        public async Task<string?> UploadBase64FileAsync(string base64Data, string folder = "prescriptions", string? publicId = null)
        {
            if (string.IsNullOrEmpty(base64Data))
            {
                return null;
            }

            // Check if it's a PDF or image based on the data URL prefix
            if (base64Data.StartsWith("data:application/pdf"))
            {
                return await UploadBase64PdfAsync(base64Data, folder, publicId);
            }
            else
            {
                return await UploadBase64ImageAsync(base64Data, folder, publicId);
            }
        }
    }
}