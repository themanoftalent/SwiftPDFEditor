import SwiftUI
import PDFKit
import AppKit

struct ContentView: View {
    @State private var document: PDFDocument?
    @State private var showImporter = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if let document = document {
                PDFViewer(document: document)
                    .toolbar {
                        Button("Save") {
                            savePDF()
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    Text(errorMessage ?? "No PDF Loaded")
                        .foregroundColor(errorMessage != nil ? .red : .gray)
                    
                    Button("Open PDF") {
                        showImporter = true
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                loadPDF(url: url)
            }
        case .failure(let error):
            errorMessage = "Failed to open file: \(error.localizedDescription)"
        }
    }
    
    private func loadPDF(url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn't access the file"
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        if let newDocument = PDFDocument(url: url) {
            document = newDocument
            errorMessage = nil
            print("Successfully loaded PDF with \(newDocument.pageCount) pages")
        } else {
            errorMessage = "Failed to load PDF file"
        }
    }
    
    private func savePDF() {
        guard let document = document else {
            errorMessage = "No document to save"
            return
        }
        
        // Check if documentURL exists; if not, prompt for a save location
        guard let originalURL = document.documentURL else {
            errorMessage = "No original URL to save to. Use 'Save As' functionality."
            return
        }
        
        // Ensure we have write access to the URL
        guard originalURL.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access the file for saving"
            return
        }
        defer { originalURL.stopAccessingSecurityScopedResource() }
        
        do {
            // Write the document to the original URL
            let success = try document.write(to: originalURL)
            if success {
                print("PDF saved successfully to \(originalURL.path)")
            } else {
                errorMessage = "Failed to save PDF: Write operation returned false"
            }
        } catch {
            errorMessage = "Failed to save PDF: \(error.localizedDescription)"
            print("Save error: \(error)")
        }
    }
}

struct PDFViewer: NSViewRepresentable {
    var document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = NSColor.controlBackgroundColor
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}
