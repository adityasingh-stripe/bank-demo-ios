//
//  ImageLoader.swift
//  BankDemo
//
//  Created by Aditya Singh
//

import UIKit
import Foundation

@MainActor
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()
    private let cache = NSCache<NSString, UIImage>()
    private let session = URLSession.shared
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            return nil
        }
        
        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache the image
            cache.setObject(image, forKey: urlString as NSString)
            return image
        } catch {
            print("Error loading image from \(urlString): \(error)")
            return nil
        }
    }
    
    func loadImage(from urlString: String?, completion: @escaping (UIImage?) -> Void) {
        Task {
            let image = await loadImage(from: urlString)
            await MainActor.run {
                completion(image)
            }
        }
    }
}

// MARK: - UIImageView Extension
extension UIImageView {
    func loadImage(from urlString: String?, placeholder: UIImage? = nil) {
        self.image = placeholder
        
        ImageLoader.shared.loadImage(from: urlString) { [weak self] image in
            self?.image = image ?? placeholder
        }
    }
} 