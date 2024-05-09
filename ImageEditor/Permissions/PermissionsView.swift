//
//  PermissionsView.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import SwiftUI
import Photos


struct PermissionsView: View {
    @State var isPickerPresented: Bool = false
    @State var selectedItem: UIImage?

    @State var status: Bool? = {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            return nil
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 16) {

                    Text(self.status == true ? "Edit Your Photos and Videos" : "Access Your Photos and Videos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.light)
                        .padding(.bottom, 8)

                    Button(action: {
                        if self.status == true {
                            isPickerPresented = true
                        } else if self.status == nil {
                            PHPhotoLibrary.requestAuthorization { status in
                                if status == .authorized || status == .limited {
                                    self.status = true
                                    return
                                }

                                self.status = false
                            }
                        }
                    }, label: {
                        Group {
                            if !isPickerPresented {
                                Text(self.status == true ? "Continue" : "Grant Permissions")
                            } else {
                                ProgressView().foregroundColor(.light)
                            }
                        }
                        .fixedSize()
                        .frame(width: geometry.size.width - 96)
                        .font(.system(size: 17, weight: .bold))
                        .padding()
                        .background(self.status == false ? Color.permissionsBackground : Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.light)
                    })
                    .disabled(self.status == false)
                }

                // Editor overlay
                if selectedItem != nil {
                    EditorView(image: selectedItem!, onClose: {
                        selectedItem = nil
                        isPickerPresented = true
                    })
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            ImagePicker(didFinishSelection: { media in
                selectedItem = media
                isPickerPresented = false
            })
            .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    PermissionsView()
}
