//
//  EditingView.swift
//  ImageEditor
//
//  Created by Andrey Ulanov on 09.05.2024.
//

import SwiftUI
import PencilKit
import AVKit
import Photos

/// Editing mode
enum DrawingMode: String, CaseIterable, Identifiable {
    case draw, text, filters
    var id: Self { self }
}

/// Filter Mode
enum ImageFilter: Hashable {
    case saturation
    case sepia
    case blur
    case exposure
}

/// Available fonts
enum TextFont: String, CaseIterable, Identifiable {
    case system, montserrat = "Montserrat-Black", pacifico = "Pacifico-Regular"
    var id: Self { self }
}

/// Text background mode
enum TextBackground: String  {
    case none = "character"
    case border = "a.square"
    case fill = "a.square.fill"
    static let allValues: [TextBackground] = [.none, .border, .fill]
}

/// Main Editor View
struct EditorView: View {
    /// Main drawing canvas
    @State private var canvas = Canvas()
    /// Canvas required for ML drawings recognition to produce perfect shapes
    @State private var mlCanvas = MLCanvas()

    /// Current tool picker showing on bottom
    @State private var toolPicker: PKToolPicker?
    /// Controller used to handle gestures applied to text views
    @State private var canvasController: CanvasViewController<Canvas>?

    /// Current editing mode
    @State private var mode: DrawingMode = .draw
    /// Font size of selected text view, in percent, actually handle point size from 12 to 64
    @State var fontSize: Float = 50.0

    /// Hint text showing at bottom when no text added/selected
    @State var infoText: String = "Tap to add text"

    /// Current text view alignment
    @State var textAlignment: NSTextAlignment = .center

    /// Available text alignments
    let textAligments: [NSTextAlignment: String] = [
        // .justified: "text.justify",
        .center: "text.aligncenter",
        .left: "text.alignleft",
        .right: "text.alignright"
    ]

    /// Available fill colors
    let fillColors: [UIColor] = [
        .white, UIColor.dark, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .systemPink, .systemRed, .systemOrange,
    ]

    /// Text colors coming with pair to display different colors on different backgrounds - white on black atd.
    let textColors: [UIColor: UIColor] = [ // fill:text
        .white: UIColor.dark,
        UIColor.dark: .white,
        .systemYellow: .white,
        .systemGreen: .white,
        .systemBlue: .white,
        .systemPurple: .white,
        .systemPink: .white,
        .systemRed: .white,
        .systemOrange: .white,
    ]

    /// Selected text view, used to provide tools for currently active text
    @State private var selectedTextView: UIView?
    /// Property showing if all text views are visible or not, used for hidding them for better drawing experience
    @State private var isTextVisible = true
    /// Is export in progress
    @State private var isProcesing = false
    @State private var isDismissAlertPresented = false
    @State private var selectedFilter: ImageFilter = .saturation
    @State private var selectedFilterAmount: Float = 0
    @State private var isSelectedFilterUsed = false

    /// Media item passed to editor - image
    var initialImage: UIImage
    @State var filterBasis: UIImage
    @State var editedImage: UIImage
    @State var appliedFilters: [(ImageFilter, Float)] = []
    /// Method called after image export is done or editing is cancelled
    let onClose: () -> Void
    /// Size of video or image, used to fit canvases to media size in contentMode equal to .fit
    @State var mediaSize: CGSize?
    /// Image view used for fit/fill image size calculatiions, native SwiftUI Image has no such capabilities
    @State var imageView = UIImageView()
    /// Image aspect mode
    @State var contentMode: ContentMode = .fit

    /// Selected text background color
    @State var fillColor: UIColor = .white
    /// Selected text background style
    @State var textStyle: TextBackground = .none
    /// Selected text font
    @State var font: TextFont = .system

    init(image: UIImage, onClose: @escaping () -> Void) {
        self.initialImage = image
        self.editedImage = image
        self.filterBasis = image
        self.onClose = onClose

        // wheel picker view background color which in sum with blur will return rgb 35,34,35
        UIPickerView.appearance().backgroundColor = UIColor(red: 17/255, green: 16/255, blue: 14/255, alpha: 1.0)

        // segmented picker style
        let appearance = UISegmentedControl.appearance()
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.dark], for: .selected)
        appearance.setTitleTextAttributes([.foregroundColor: UIColor.light], for: .normal)
        UISegmentedControl.appearance().backgroundColor = UIColor(red: 21/255, green: 21/255, blue: 17/255, alpha: 1.0) // visible as 44,44,44
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 244/255, green: 244/255, blue: 244/255, alpha: 1.0)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Toolbar
                ZStack(alignment: .center) {
                    // Font picker
                    if (selectedTextView != nil) {
                        if mode == .text {
                            Picker("Font", selection: $font) {
                                Text("Default Font")
                                    .font(.system(size: 20))
                                    .tag(TextFont.system)
                                Text("Montserrat")
                                    .font(Font.custom("Montserrat", size: 20))
                                    .tag(TextFont.montserrat)
                                Text("Pacifico")
                                    .font(Font.custom("Pacifico-Regular", size: 20))
                                    .tag(TextFont.pacifico)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: UIScreen.main.bounds.width, height: 56).clipped()
                            .frame(width: 128, height: 32).clipped()
                            .onChange(of: font, { oldValue, newValue in
                                onFontChanged(newValue)
                            })
                        }
                    }

                    HStack {
                        Button(action: clearAll) {
                            Text("Clear All")
                                .frame(height: 36)
                                .padding(.horizontal, 12)
                                .foregroundColor(.light)
                                .background(Color.darkHighlight)
                                .clipShape(Rectangle())
                                .cornerRadius(36)
                                .padding(.all, 4)
                        }

                        Spacer()

                        ShareLink(
                            item: Image(uiImage: editedImage),
                            subject: nil,
                            message: nil,
                            preview: SharePreview("Edited Image", image: Image(uiImage: editedImage))
                        )
                    }
                    .padding(.all, 8)
                }
                .disabled(isProcesing)

                Spacer()

                // Media view
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .local)
                    let size = calculateCanvasSize(bounds: geometry.size)

                    Group {
                        // Image
                        ImageView(
                            image: Binding(get: { editedImage }, set: { _ in }),
                            imageView: imageView,
                            contentMode: Binding(
                                get: { contentMode == .fit ? .scaleAspectFit : .scaleAspectFill },
                                set: { _ in }
                            )
                        )
                        .onChange(of: initialImage) { calculateImageSize(frame) }
                        .onAppear {
                            // get image size for .fit content mode
                            calculateImageSize(frame)
                        }
                    }
//                    .allowsHitTesting(false)  required to passthough touch events to ML Canvas
                    .background(
                        // ML canvas
                        CanvasView(canvas: $mlCanvas, shouldBecameFirstResponder: false)
                        .frame(width: size.width,
                               height: size.height)
                    )
                    .overlay(
                        // Main drawing canvas
                        CanvasView(canvas: $canvas, onChanged: { drawing in }, onSelectionChanged: selectionChanged)
                            .onAppear {
                                mlCanvas.mainCanvas = canvas
                                canvas.mlCanvas = mlCanvas
                            }
                            .frame(width: size.width,
                                   height: size.height)

                    )
                }

                Spacer()

                // Bottom tool bar
                VStack(spacing: 0) {
                    HStack {
                        // Close button
                        Button(action: {
                            isDismissAlertPresented = true
                        }) {
                            CircleIcon(systemName: "xmark").padding(.all, 4)
                        }

                        // Mode switcher
                        Picker("Mode", selection: $mode) {
                            Text("Draw").tag(DrawingMode.draw)
                            Text("Text").tag(DrawingMode.text)
                            Text("Filters").tag(DrawingMode.filters)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mode) { modeChanged($1) }

                        // Save button
                        Button(action: export) {
                            CircleIcon(systemName: "arrow.down", hidden: isProcesing)
                                .padding(.all, 4)
                                .overlay(
                                    isProcesing ? ProgressView().foregroundColor(.light) : nil
                                )
                        }
                    }
                    .frame(height: 50)
                    .padding(.horizontal, 8)
                    .background(Color.dark)
                    .disabled(isProcesing)

                    HStack {
                        switch mode {
                        case .draw:
                            isDismissAlertPresented ? AnyView(Color.dark) : AnyView(Color(red: 29/255, green: 28/255, blue: 30/255)
                                .onTapGesture {
                                    activateCanvas()
                                })
                        case .text:
                            ZStack(alignment: .center) {
                                Color.dark.blendMode(BlendMode.sourceAtop).edgesIgnoringSafeArea(.all)
                                if (selectedTextView != nil) {
                                    HStack {

                                        // Text background color picker
                                        Button(action: colorTapped) {
                                            Circle()
                                                .fill(Color(fillColor))
                                                .frame(width: 33, height: 33)
                                                .overlay(
                                                    Circle().stroke(Color.light, lineWidth: 3)
                                                )
                                                .padding(.leading, 14)
                                                .padding(.trailing, 5)
                                        }

                                        // Text Background switcher
                                        Button(action: textStyleTapped) {
                                            Image(systemName: "character")
                                                .frame(width: 34, height: 34)
                                                .foregroundColor(textStyle == .fill ? .dark : .light)
                                                .background(textStyle == .fill ? Color.light : Color.darkHighlight)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(textStyle == .none ? Color.darkHighlight : Color.light, lineWidth: 2)
                                                )
                                        }
                                        .padding(.vertical, 4)

                                        // Brush size slider
                                        FontSlider(
                                            progress: $fontSize,
                                            foregroundColor: .light,
                                            backgroundColor: .darkHighlight
                                        )
                                        .frame(height: 36)
                                        .onChange(of: fontSize) { onFontSizeChanged($1) }

                                        Spacer()

                                        // Alignment switcher
                                        Button(action: alingTextTapped) {
                                            CircleIcon(systemName: textAligments[textAlignment] ?? "text.aligncenter")
                                                .padding(.all, 4)
                                        }

                                        Button(action: addText) {
                                            CircleIcon(systemName: "plus")
                                        }
                                        .padding(.leading, 4)
                                        .padding(.trailing, 14)
                                    }
                                } else {
                                    // Text hint
                                    Text(!isTextVisible ? "Hide text mode is active" : infoText).fontWeight(.bold).foregroundColor(.light)
                                        .onTapGesture {
                                            if isTextVisible {
                                                addText()
                                            }
                                        }
                                }
                            }
                        case .filters:
                            VStack {
                                HStack {
                                    Picker("Filter", selection: $selectedFilter) {
                                        Text("Sepia").tag(ImageFilter.sepia)
                                        Text("Saturation").tag(ImageFilter.saturation)
                                        Text("Blur").tag(ImageFilter.blur)
                                        Text("Exposure").tag(ImageFilter.exposure)
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(.white)
                                }

                                HStack {
                                    Text("Amount:")
                                    Slider(value: $selectedFilterAmount, in: 0...1)
                                }
                            }
                            .padding(.horizontal)
                            .onChange(of: selectedFilterAmount, { _, value in
                                guard let result = applyFilter(on: filterBasis, selectedFilter, amount: value)
                                else {
                                    return
                                }
                                editedImage = result
                                isSelectedFilterUsed = true
                            })
                            .onChange(of: selectedFilter) { oldValue, newValue in
                                if isSelectedFilterUsed {
                                    isSelectedFilterUsed = false
                                    appliedFilters.append((oldValue, selectedFilterAmount))
                                    var newBasis = initialImage
                                    appliedFilters.forEach { (filter, amount) in
                                        guard let image = applyFilter(on: newBasis, filter, amount: amount) else {
                                            return
                                        }
                                        newBasis = image
                                    }
                                    filterBasis = newBasis
                                }
                            }
                        }
                    }
                    .frame(height: 75.0)
                    .animation(mode == .draw ? .easeIn(duration: 0.05).delay(mode == .text ? 0.0 : 0.4) : nil, value: mode)
                }
            }
            .background(Color.dark.edgesIgnoringSafeArea(.all))
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .alert(isPresented: self.$isDismissAlertPresented) {
            // Cancelation alert
            Alert(
                title: Text("Are you sure?"),
                message: Text("Changes will not be saved"),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .destructive(Text("Leave"), action: {
                    close()
                })
            )
        }
    }

    /// Leave editor view, clean up local states
    func close() {
        defer { onClose() }
        mode = .draw

        toolPicker?.isRulerActive = false
        toolPicker?.setVisible(false, forFirstResponder: canvas)
        canvas.isUserInteractionEnabled = false
        mlCanvas.isUserInteractionEnabled = false

        contentMode = .fit
        isTextVisible = true
        mediaSize = nil

        let labels: [UIView] = canvasController?.view.subviews.filter { $0 is UILabel } ?? []

        if ((canvas.drawing.strokes.isEmpty || canvas.drawing.bounds.isEmpty) && labels.isEmpty) {
            // empty canvas
            return
        }

        canvas.drawing = PKDrawing()
        mlCanvas.drawing = PKDrawing()
        canvas.undoManager?.removeAllActions()

        for label in labels {
            label.removeFromSuperview()
        }

        resetSelection()
    }

    /// Method called on font changes
    func onFontChanged(_ value: TextFont) {
        guard let label = selectedTextView as? TextLabel else { return }
        let size = label.font.pointSize
        switch value {
        case .system:
            label.font = .systemFont(ofSize: size)
        case .montserrat:
            label.font = .init(name: "Montserrat", size: size)
        case .pacifico:
            label.font = .init(name: "Pacifico-Regular", size: size)
        }

        // resize
        let labelSize = label.intrinsicContentSize
        label.bounds.size = CGSize(width: labelSize.width + 32, height: labelSize.height + 24)
    }


    /// Hide all text views, adding new text will deactivate hidden mode
    func hideTextViews() {
        isTextVisible.toggle()

        changeTextsVisibility(visible: isTextVisible)

        resetSelection()
    }

    /// Clear all the drawings and texts with ability to undo clearing process
    func clearAll() {
        editedImage = initialImage
        filterBasis = initialImage
        appliedFilters = []

        let labels: [UIView] = canvasController?.view.subviews.filter { $0 is UILabel } ?? []

        if ((canvas.drawing.strokes.isEmpty || canvas.drawing.bounds.isEmpty) && labels.isEmpty) {
            // empty canvas
            return
        }

        // MARK: Coment code behind to also clear the undo action of clearing all
        let original = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: canvas, handler: {
            $0.drawing = original

            for label in labels {
                canvasController?.view.addSubview(label)
            }
        })
        canvas.drawing = PKDrawing()

        mlCanvas.drawing = PKDrawing()

        for label in labels {
            label.removeFromSuperview()
        }

        resetSelection()
    }

    /// Show text entering view
    func addText() {
        if (canvasController == nil) {
            canvasController = canvas.parentViewController as? CanvasViewController<Canvas>
        }

        canvasController?.showTextAlert(title: "Add text", text: nil, actionTitle: "Add") { text in
            addTextView(text)
        }
    }

    func applyFilter(_ filter: ImageFilter, amount: Float) -> UIImage? {
        appliedFilters.forEach { (filter, amount) in

        }
        return switch filter {
        case .saturation:
            initialImage.applySaturation(amount)
        case .sepia:
            initialImage.applySepia(amount)
        case .blur:
            initialImage.applyBlur(amount)
        case .exposure:
            initialImage.applyExposure(amount)
        }
    }

    func applyFilter(on image: UIImage, _ filter: ImageFilter, amount: Float) -> UIImage? {
        return switch filter {
        case .saturation:
            image.applySaturation(amount)
        case .sepia:
            image.applySepia(amount)
        case .blur:
            image.applyBlur(amount)
        case .exposure:
            image.applyExposure(amount)
        }
    }

    /// Method called on text background color changes
    func colorTapped() {
        guard let label = selectedTextView as? TextLabel, let old = fillColors.firstIndex(where: {
            switch (textStyle) {
            case .none, .border:
                return label.textColor == $0
            case .fill:
                return label.layer.backgroundColor == $0.cgColor
            }
        }) else { return }

        let index = (old + 1) < fillColors.count ? old + 1 : 0
        switch (textStyle) {
        case .none:
            label.textColor = fillColors[index]
            label.backgroundColor = .clear
            label.layer.backgroundColor = UIColor.clear.cgColor
            break
        case .border:
            label.textColor = fillColors[index]
            label.backgroundColor = .clear
            label.layer.backgroundColor = UIColor.clear.cgColor
            label.layer.borderColor = fillColors[index].cgColor
            label.styledLayer.borderColor = fillColors[index].cgColor
            break
        case .fill:
            let color = fillColors[index]
            label.backgroundColor = color
            label.layer.backgroundColor = color.cgColor
            label.textColor = textColors[color]
            break
        }

        fillColor = fillColors[index]
    }

    /// Method called on brish size slider changes
    func onFontSizeChanged(_ value: Float) {
        guard let label = selectedTextView as? UILabel else { return }

        // font size from 12 to 64
        label.font = label.font.withSize(CGFloat(value * 52.0) / 100.0 + 12.0)

        // resize
        let labelSize = label.intrinsicContentSize
        label.bounds.size = CGSize(width: labelSize.width + 32, height: labelSize.height + 24)
    }

    /// Method to align currently selected text
    func alingTextTapped() {
        guard let label = selectedTextView as? UILabel else { return }
        switch (textAlignment) {
        case .left: textAlignment = .center; break
        case .center: textAlignment = .right; break
        case .right: textAlignment = .left; break
        default: return
        }
        label.textAlignment = textAlignment
    }

    /// Update text view background style
    func textStyleTapped() {
        guard let label = selectedTextView as? TextLabel else { return }

        switch (textStyle) {
        case .none:
            textStyle = .border
            // border
            label.backgroundColor = .clear
            label.layer.backgroundColor = UIColor.clear.cgColor
            label.layer.borderWidth = 3
            // label.layer.borderColor = UIColor.white.cgColor
            label.layer.borderColor = label.textColor.cgColor
            label.tag = 1
            fillColor = label.textColor
            break
        case .border:
            textStyle = .fill
            // fill
            label.textColor = textColors[.white]
            label.backgroundColor = .white
            label.layer.backgroundColor = UIColor.white.cgColor
            label.layer.borderWidth = 0
            label.tag = 2
            fillColor = .white
            break
        case .fill:
            textStyle = .none
            // simple
            label.layer.backgroundColor = UIColor.clear.cgColor
            label.backgroundColor = .clear
            label.layer.borderWidth = 0
            label.tag = 0
            fillColor = label.textColor
            //fillColor = UIColor(cgColor: label.layer.backgroundColor ?? UIColor.white.cgColor)
            break
        }
        label.styledLayer = label.layer.copied
    }

    /// Save drawings and texts with selected video or image to user's media library
    func export() {
        withAnimation {
            isProcesing = true
        }

        if (canvasController == nil) {
            canvasController = canvas.parentViewController as? CanvasViewController<Canvas>
        }
        guard let canvasController = canvasController else { return }

        // render controller view (contains drawing and text views)
        let renderer = UIGraphicsImageRenderer(size: canvasController.view.bounds.size)
        let markup = renderer.image { ctx in
            canvasController.view.drawHierarchy(in: canvasController.view.bounds, afterScreenUpdates: true)
        }
        // optionally drawing may be exported directly from canvas
        // let markup = canvas.drawing.image(from: canvas.bounds, scale: 1.0)


        MediaProcessor.exportImage(image: editedImage, markup: markup, contentMode: contentMode, imageView: imageView)

        withAnimation { isProcesing = false }
        close()
    }

    /// Save drawings and texts with selected video or image to user's media library
    func result() -> UIImage {
        if (canvasController == nil) {
            canvasController = canvas.parentViewController as? CanvasViewController<Canvas>
        }
        guard let canvasController = canvasController else { return editedImage }

        // render controller view (contains drawing and text views)
        let renderer = UIGraphicsImageRenderer(size: canvasController.view.bounds.size)
        let markup = renderer.image { ctx in
            canvasController.view.drawHierarchy(in: canvasController.view.bounds, afterScreenUpdates: true)
        }
        // optionally drawing may be exported directly from canvas
        // let markup = canvas.drawing.image(from: canvas.bounds, scale: 1.0)


        let image = MediaProcessor.makeImage(image: editedImage, markup: markup, contentMode: contentMode, imageView: imageView)
        return image
    }

    /// Helper method to hide/show all text views
    func changeTextsVisibility(visible: Bool) {
        for view in canvasController?.view.subviews ?? [] {
            if (view is UILabel) {
                view.isHidden = !visible
            }
        }
    }

    /// Dynamic canvas size depending on media type and content mode (aspect ratio)
    func calculateCanvasSize(bounds: CGSize) -> CGSize {
        if contentMode == .fill {
            return bounds
        } else {
            return imageView.aspectFitSize
        }
    }

    /// Calculate image fit size
    func calculateImageSize(_ frame: CGRect) {
        guard contentMode == .fit else { return }

        let size = initialImage.size

        var newWidth: CGFloat
        var newHeight: CGFloat

        if size.height >= size.width {
            newHeight = frame.size.height
            newWidth = ((size.width / (size.height)) * newHeight)

            if CGFloat(newWidth) > (frame.size.width) {
                let diff = (frame.size.width) - newWidth
                newHeight = newHeight + CGFloat(diff) / newHeight * newHeight
                newWidth = frame.size.width
            }
        } else {
            newWidth = frame.size.width
            newHeight = (size.height / size.width) * newWidth

            if newHeight > frame.size.height {
                let diff = Float((frame.size.height) - newHeight)
                newWidth = newWidth + CGFloat(diff) / newWidth * newWidth
                newHeight = frame.size.height
            }
        }

        mediaSize = CGSize(width: newWidth, height: newHeight)
    }

    /// Editing mode changed - update UI
    func modeChanged(_ selected: DrawingMode) {
        if canvasController == nil {
            canvasController = canvas.parentViewController as? CanvasViewController<Canvas>
        }
        if (toolPicker == nil) {
            toolPicker = canvasController?.toolPicker
        }

        // show/hide PKToolPicker
        if (selected == .text || selected == .filters) {
            toolPicker?.isRulerActive = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                toolPicker?.setVisible(false, forFirstResponder: canvas)
                canvas.isUserInteractionEnabled = false
                mlCanvas.isUserInteractionEnabled = false
            })

            let labels: [UIView] = canvasController?.view.subviews.filter { $0 is UILabel } ?? []
            infoText = labels.isEmpty ? "Tap to add text" : "Tap any text to customize"

            canvasController?.selectionEnabled = true
        } else {
            activateCanvas()

            canvas.isUserInteractionEnabled = true
            mlCanvas.isUserInteractionEnabled = true
            toolPicker?.setVisible(true, forFirstResponder: canvas)

            activateCanvas()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                activateCanvas()
            })

            canvasController?.selectionEnabled = false
        }
        resetSelection()
    }

    /// Set first responder to main canvas
    func activateCanvas() {
        canvas.becomeFirstResponder()
        canvas.resignFirstResponder()
        canvas.becomeFirstResponder()
    }

    /// Deselect text view
    func resetSelection() {
        if let view = selectedTextView {
            canvasController?.deselectSubview(view)
        }
        textAlignment = .center
    }

    /// Insert new text view as canvas controller subview
    func addTextView(_ text: String) {
        guard let controller = canvasController else { return }
        let label = TextLabel(frame: CGRect(x: controller.view.center.x - 128, y: controller.view.center.y - 64, width: 256, height: 128))
        label.accessibilityIdentifier = "textview_\(Int.random(in: 0..<65536))"
        label.numberOfLines = 0

        label.text = text
        label.textColor = .white
        label.textAlignment = .center

        let labelSize = label.intrinsicContentSize
        label.bounds.size = CGSize(width: labelSize.width + 32, height: labelSize.height + 24)

        label.layer.cornerRadius = 16
        label.layer.borderWidth = 3
        label.layer.borderColor = UIColor.white.cgColor
        label.tag = 1
        label.layer.masksToBounds = true
        label.styledLayer = label.layer.copied

        label.isHidden = !isTextVisible

        // enable multiple touch and user interaction
        label.isUserInteractionEnabled = true
        label.isMultipleTouchEnabled = true

        canvas.undoManager?.registerUndo(withTarget: canvas, handler: { _ in
            label.removeFromSuperview()
        })

        controller.registerGestures(for: label)
        controller.view.addSubview(label)

        resetSelection()
        controller.selectSubview(label)

        if isTextVisible == false {
            isTextVisible = true
            changeTextsVisibility(visible: true)
        }
    }

    /// Text view selectiong changed
    func selectionChanged(_ view: UIView?) {
        selectedTextView = view

        let label = view as? UILabel

        let pointSize = Float(label?.font.pointSize ?? 17.0)
        fontSize = ((pointSize - 12.0) * 100.0) / 52.0

        textAlignment = label?.textAlignment ?? .center

        guard let index = label?.tag, index >= 0, index < TextBackground.allValues.count else { return }
        textStyle = TextBackground.allValues[index]

        switch (textStyle) {
        case .none, .border:
            fillColor = label?.textColor ?? .white
            break
        case .fill:
            fillColor = label?.backgroundColor ?? .white
            break
        }

        // font
        switch label?.font.fontName {
        case TextFont.montserrat.rawValue:
            font = .montserrat
        case TextFont.pacifico.rawValue:
            font = .pacifico
        default:
            font = .system
        }

        infoText = "Tap any text to customize"
    }
}

#Preview {
    EditorView(image: UIImage(resource: .beach), onClose: { })
}
