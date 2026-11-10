import Foundation
import PDFKit
import SwiftUI
import UIKit

struct MEPPracticeBookPageView: View {
    let urlString: String
    let pageNumber: Int
    let printedPageNumber: Int?
    let onTextLoaded: (String) -> Void

    @State private var pageImage: UIImage?
    @State private var loadError: String?
    @State private var loading = true

    var body: some View {
        Group {
            if let pageImage {
                Image(uiImage: pageImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .accessibilityLabel("Original Practice Book page \(printedPageNumber ?? pageNumber)")
            } else if loading {
                ProgressView("Loading original Practice Book page…")
                    .frame(maxWidth: .infinity, minHeight: 500)
            } else {
                ContentUnavailableView(
                    "Practice Book page unavailable",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(loadError ?? "Check your internet connection and try again.")
                )
                .frame(maxWidth: .infinity, minHeight: 500)
            }
        }
        .background(.white)
        .task(id: "\(urlString)#\(pageNumber)") { await loadPage() }
    }

    @MainActor
    private func loadPage() async {
        loading = true
        loadError = nil
        defer { loading = false }

        guard let url = URL(string: urlString) else {
            loadError = "The Practice Book link is invalid."
            return
        }

        do {
            let data = try await cachedPDFData(from: url)
            guard let document = PDFDocument(data: data),
                  let page = document.page(at: pageNumber - 1) else {
                loadError = "The linked PDF does not contain this page."
                return
            }
            pageImage = page.thumbnail(of: CGSize(width: 1600, height: 2263), for: .mediaBox)
            onTextLoaded(page.string ?? "")
        } catch {
            loadError = "Could not load the original Practice Book PDF. Check the connection and retry."
        }
    }

    private func cachedPDFData(from url: URL) async throws -> Data {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MEPPracticeBooks", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let fileURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        if let cached = try? Data(contentsOf: fileURL) { return cached }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try data.write(to: fileURL, options: .atomic)
        return data
    }
}
