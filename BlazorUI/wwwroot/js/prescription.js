// Prescription related JavaScript functions

// Function to capture an element as base64 image using html2canvas
window.captureElementAsBase64 = async function (elementId) {
    try {
        console.log('captureElementAsBase64 called with elementId:', elementId);
        
        const element = document.getElementById(elementId);
        if (!element) {
            console.error('Element not found:', elementId);
            return null;
        }
        console.log('Element found:', element);

        // Check if html2canvas is available
        if (typeof html2canvas === 'undefined') {
            console.error('html2canvas library not loaded!');
            return null;
        }
        console.log('html2canvas is available');

        // Use html2canvas to capture the element with optimized settings
        const canvas = await html2canvas(element, {
            scale: 1.5, // Reduced from 2 for smaller file size
            useCORS: true,
            logging: false,
            backgroundColor: '#ffffff',
            allowTaint: true,
            imageTimeout: 5000,
            removeContainer: true
        });
        console.log('Canvas created successfully');

        // Convert canvas to base64 JPEG (smaller than PNG)
        const base64 = canvas.toDataURL('image/jpeg', 0.8);
        console.log('Base64 length:', base64.length);
        
        // Return the full data URL so the API knows it's JPEG
        return base64;
    } catch (error) {
        console.error('Error capturing element:', error);
        console.error('Error stack:', error.stack);
        return null;
    }
};

// Function to generate PDF from prescription HTML content
window.generatePrescriptionPdf = async function (elementId) {
    try {
        console.log('generatePrescriptionPdf called with elementId:', elementId);
        
        const element = document.getElementById(elementId);
        if (!element) {
            console.error('Element not found:', elementId);
            return null;
        }

        // Check if jspdf is available
        if (typeof window.jspdf === 'undefined' && typeof jspdf === 'undefined') {
            console.error('jsPDF library not loaded!');
            return null;
        }

        const { jsPDF } = window.jspdf || jspdf;
        
        // Create a new PDF document
        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'mm',
            format: 'a4',
            compress: true
        });

        // Use html2canvas to render the element first, then add to PDF
        if (typeof html2canvas !== 'undefined') {
            try {
                const canvas = await html2canvas(element, {
                    scale: 1.5, // Reduced for smaller size
                    useCORS: true,
                    logging: false,
                    backgroundColor: '#ffffff',
                    imageTimeout: 5000
                });
                
                // Use JPEG for smaller file size
                const imgData = canvas.toDataURL('image/jpeg', 0.7);
                const imgWidth = 210; // A4 width in mm
                const pageHeight = 297; // A4 height in mm
                const imgHeight = (canvas.height * imgWidth) / canvas.width;
                
                pdf.addImage(imgData, 'JPEG', 0, 0, imgWidth, Math.min(imgHeight, pageHeight));
                
                // Get the PDF as base64 with full data URL
                const pdfBase64 = pdf.output('datauristring');
                console.log('PDF generated successfully, length:', pdfBase64.length);
                return pdfBase64;
            } catch (canvasError) {
                console.error('html2canvas failed, falling back to text-based PDF:', canvasError);
            }
        }

        // Fallback: Create a simple text-based PDF from the HTML content
        const text = element.innerText || element.textContent;
        const lines = text.split('\n').filter(line => line.trim());
        
        let yPosition = 20;
        const lineHeight = 7;
        const margin = 15;
        const pageWidth = 210 - (margin * 2);

        pdf.setFontSize(12);
        
        for (const line of lines) {
            if (yPosition > 280) {
                pdf.addPage();
                yPosition = 20;
            }
            
            // Word wrap long lines
            const words = line.split(' ');
            let currentLine = '';
            
            for (const word of words) {
                const testLine = currentLine + (currentLine ? ' ' : '') + word;
                const textWidth = pdf.getTextWidth(testLine);
                
                if (textWidth > pageWidth && currentLine) {
                    pdf.text(currentLine, margin, yPosition);
                    yPosition += lineHeight;
                    currentLine = word;
                    
                    if (yPosition > 280) {
                        pdf.addPage();
                        yPosition = 20;
                    }
                } else {
                    currentLine = testLine;
                }
            }
            
            if (currentLine) {
                pdf.text(currentLine, margin, yPosition);
                yPosition += lineHeight;
            }
        }
        
        const pdfBase64 = pdf.output('datauristring').split(',')[1];
        console.log('Text-based PDF generated, length:', pdfBase64.length);
        return pdfBase64;
        
    } catch (error) {
        console.error('Error generating PDF:', error);
        return null;
    }
};

// Simple function to get HTML content as string for server-side PDF generation
window.getPrescriptionHtml = function (elementId) {
    try {
        const element = document.getElementById(elementId);
        if (!element) {
            console.error('Element not found:', elementId);
            return null;
        }
        return element.innerHTML;
    } catch (error) {
        console.error('Error getting HTML:', error);
        return null;
    }
};
