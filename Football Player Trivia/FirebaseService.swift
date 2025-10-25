//
//  FirebaseService.swift
//  Baseball Player Trivia
//
//  Secure backend service using Firebase Cloud Functions
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import FirebaseAuth

// Response structure for answer validation
struct AnswerValidationResponse {
    let isCorrect: Bool
    let message: String
}

class FirebaseService {
    static let shared = FirebaseService()
    
    private let functions = Functions.functions()
    private var currentUser: User?
    
    private init() {
        // Delay sign-in to not block initial UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.signInAnonymously()
        }
    }
    
    // Sign in anonymously to get a user ID for rate limiting
    private func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error = error {
                print("Anonymous sign-in error: \(error.localizedDescription)")
                return
            }
            self?.currentUser = result?.user
            print("Anonymous user signed in: \(result?.user.uid ?? "unknown")")
        }
    }
    
    // Generate a hint using Cloud Function
    func generateHint(for players: [Player], position: String, year: Int, team: String, hintLevel: String, completion: @escaping (Result<String, Error>) -> Void) {
        
        let playersData = players.map { player in
            return [
                "firstName": player.firstName,
                "lastName": player.lastName
            ]
        }
        
        let data: [String: Any] = [
            "correctPlayers": playersData,
            "position": position,
            "year": year,
            "team": team,
            "hintLevel": hintLevel
        ]
        
        functions.httpsCallable("generateHint").call(data) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = result?.data as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
                return
            }
            
            // Check for errors
            if let _ = data["error"] as? String,
               let message = data["message"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }
            
            // Get hint
            if let hint = data["hint"] as? String {
                DispatchQueue.main.async {
                    completion(.success(hint))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No hint in response"])))
                }
            }
        }
    }
    
    // Validate answer using Cloud Function
    func validateAnswerAndProvideInfo(
        userAnswer: String,
        correctPlayers: [Player],
        position: String,
        year: Int,
        team: String,
        completion: @escaping (Result<AnswerValidationResponse, Error>) -> Void
    ) {
        
        let playersData = correctPlayers.map { player in
            return [
                "firstName": player.firstName,
                "lastName": player.lastName
            ]
        }
        
        let data: [String: Any] = [
            "userAnswer": userAnswer,
            "correctPlayers": playersData,
            "position": position,
            "year": year,
            "team": team
        ]
        
        functions.httpsCallable("validateAnswer").call(data) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let responseData = result?.data as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
                return
            }
            
            // Check for fallback response (rate limit or budget exceeded)
            if let fallbackData = responseData["fallback"] as? [String: Any],
               let message = fallbackData["message"] as? String,
               let isCorrect = fallbackData["isCorrect"] as? Bool {
                let response = AnswerValidationResponse(
                    isCorrect: isCorrect,
                    message: message
                )
                DispatchQueue.main.async {
                    completion(.success(response))
                }
                return
            }
            
            // Normal response
            if let message = responseData["message"] as? String,
               let isCorrect = responseData["isCorrect"] as? Bool {
                let response = AnswerValidationResponse(
                    isCorrect: isCorrect,
                    message: message
                )
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Incomplete response data"])))
                }
            }
        }
    }
}
