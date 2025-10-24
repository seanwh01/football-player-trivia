//
//  Football_Player_TriviaApp.swift
//  Football Player Trivia
//
//  Created by SEAN WHITE on 10/24/25.
//

import SwiftUI
import CoreData

@main
struct Football_Player_TriviaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
