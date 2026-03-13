import SwiftUI

// MARK: - Form Sections
extension ItemEditView {
    // MARK: Title Section
    var titleSection: some View {
        Section("Item Title") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TextField("Enter item name", text: $viewModel.title)
                    .textFieldStyle(.plain)
                    .autocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .focused($isTitleFieldFocused)
                    .onChange(of: viewModel.title) { newValue in
                        handleTitleChange(newValue)
                    }

                // Suggestions with enhanced Phase 14 functionality
                if showingSuggestions && !suggestionService.suggestions.isEmpty {
                    SuggestionListView(
                        suggestions: suggestionService.suggestions,
                        onSuggestionTapped: { suggestion in
                            applySuggestion(suggestion)
                        },
                        showAllSuggestions: showAllSuggestions,
                        onShowAllToggled: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAllSuggestions.toggle()
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    .onAppear {
                        // Show tooltip when suggestions first appear
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            tooltipManager.showIfNeeded(.itemSuggestions)
                        }
                    }
                }

                if viewModel.showTitleError {
                    Text(viewModel.titleErrorMessage)
                        .foregroundColor(Theme.Colors.error)
                        .font(Theme.Typography.caption)
                }
            }
        }
    }

    // MARK: Description Section
    var descriptionSection: some View {
        Section("Description (Optional)") {
            TextEditor(text: $viewModel.description)
                .frame(minHeight: 80, maxHeight: 200)
                .focused($isDescriptionFieldFocused)

            Text("\(viewModel.description.count)/50,000 characters")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if viewModel.showDescriptionError {
                Text(viewModel.descriptionErrorMessage)
                    .foregroundColor(Theme.Colors.error)
                    .font(Theme.Typography.caption)
            }
        }
    }

    // MARK: Quantity Section
    var quantitySection: some View {
        Section("Quantity") {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Quantity")
                        .font(.title2)
                        .fontWeight(.medium)

                    Spacer()

                    Stepper(
                        value: $localQuantity,
                        in: 1...9999,
                        step: 1
                    ) {
                        Text("\(localQuantity)")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .onChange(of: localQuantity) { newValue in
                        viewModel.quantity = newValue
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)

            if viewModel.showQuantityError {
                Text(viewModel.quantityErrorMessage)
                    .foregroundColor(Theme.Colors.error)
                    .font(Theme.Typography.caption)
            }
        }
    }

    // MARK: Images Section
    // Task 16.13: Show explicit 10-image limit with visual feedback
    var imagesSection: some View {
        Section("Images") {
            VStack(spacing: Theme.Spacing.md) {
                // Add Image Button - disabled at 10 image limit
                let isAtImageLimit = viewModel.images.count >= 10
                Button(action: {
                    showingImageSourceSelection = true
                }) {
                    HStack {
                        Image(systemName: isAtImageLimit ? "exclamationmark.circle.fill" : "plus.circle.fill")
                            .foregroundColor(isAtImageLimit ? Theme.Colors.secondary : Theme.Colors.primary)
                            .font(.title2)

                        Text(isAtImageLimit ? String(localized: "Image Limit Reached") : String(localized: "Add Photo"))
                            .foregroundColor(isAtImageLimit ? Theme.Colors.secondary : Theme.Colors.primary)
                            .font(.headline)

                        Spacer()

                        // Show count/limit indicator
                        Text("\(viewModel.images.count)/10")
                            .font(Theme.Typography.caption)
                            .foregroundColor(viewModel.images.count >= 8 ? .orange : Theme.Colors.secondary)
                            .padding(.horizontal, Theme.Spacing.xs)

                        if !isAtImageLimit {
                            Image(systemName: "camera.fill")
                                .foregroundColor(Theme.Colors.secondary)
                            Image(systemName: "photo.fill")
                                .foregroundColor(Theme.Colors.secondary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.groupedBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isAtImageLimit)

                // Display existing images with reordering arrows
                if !viewModel.images.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Use arrows to reorder images")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.Spacing.sm) {
                            ForEach(viewModel.images.indices, id: \.self) { index in
                                DraggableImageThumbnailView(
                                    itemImage: viewModel.images[index],
                                    index: index,
                                    totalImages: viewModel.images.count,
                                    onDelete: {
                                        viewModel.removeImage(at: index)
                                    },
                                    onMove: { fromIndex, toIndex in
                                        viewModel.moveImage(from: fromIndex, to: toIndex)
                                    }
                                )
                            }
                        }
                    }
                }

                // Image count and size info
                if !viewModel.images.isEmpty {
                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(Theme.Colors.secondary)
                        Text("\(viewModel.images.count) image\(viewModel.images.count == 1 ? "" : "s")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)

                        Spacer()

                        let totalSize = viewModel.images.compactMap { $0.imageData?.count }.reduce(0, +)
                        Text(imageService.formatFileSize(totalSize))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondary)
                    }
                }
            }
        }
    }
}
