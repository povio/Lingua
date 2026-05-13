//
//  ProgressOverlay.swift
//  Lingua
//
//  Created by Egzon Arifi on 22/08/2023.
//

import SwiftUI

struct ProgressOverlay: View {
  var isProgressing: Bool
  var text: String

  var body: some View {
    if isProgressing {
      ZStack {
        Color(NSColor.windowBackgroundColor).opacity(0.5)
        ProgressView(text)
          .padding()
          .background(Color(NSColor.windowBackgroundColor))
          .cornerRadius(10)
          .shadow(radius: 10)
          .padding(40)
      }
    }
  }
}
