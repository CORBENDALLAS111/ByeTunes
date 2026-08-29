import SwiftUI
import PhotosUI

struct AlbumMetadataEditor: View {
    let album: DeviceLibraryBrowserView.AlbumEntry
    let initialArtworkData: Data?
    @Binding var isPresented: Bool
    var onSave: (_ artist: String, _ album: String, _ genre: String, _ year: Int, _ artworkData: Data?, _ explicitRating: Int?) -> Void

    @State private var albumName: String = ""
    @State private var artist: String = ""
    @State private var genre: String = ""
    @State private var year: String = ""
    @State private var isExplicit: Bool = false

    @State private var artworkItem: PhotosPickerItem?
    @State private var artworkData: Data?

    @FocusState private var focusedField: Field?

    private enum Field {
        case albumName, artist, genre, year
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let data = artworkData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            } else {
                                ZStack {
                                    Color(uiColor: .systemGray5)
                                    Image(systemName: "square.stack")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 140, height: 140)
                                .cornerRadius(12)
                            }

                            PhotosPicker(selection: $artworkItem, matching: .images) {
                                Label("Change Artwork", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Artwork")
                } footer: {
                    Text("Applies to all \(album.songs.count) track\(album.songs.count == 1 ? "" : "s") in this album.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Album")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("Enter album name", text: $albumName)
                            .focused($focusedField, equals: .albumName)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Album Artist")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("Enter artist", text: $artist)
                            .focused($focusedField, equals: .artist)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Genre")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("Enter genre", text: $genre)
                            .focused($focusedField, equals: .genre)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Year")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("YYYY", text: $year)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .year)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $isExplicit) {
                        HStack(spacing: 8) {
                            Text("🅴")
                                .font(.caption.weight(.black))
                                .foregroundColor(.red)
                            Text("Explicit")
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Details")
                } footer: {
                    Text("These changes apply to every track in the album at once.")
                }
            }
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                loadFieldsFromAlbum()
            }
            .onChange(of: artworkItem, perform: { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.artworkData = data
                        }
                    }
                }
            })
        }
    }

    private func loadFieldsFromAlbum() {
        albumName = album.name
        artist = album.artist
        genre = album.songs.first?.genre ?? ""
        let representativeYear = album.songs.first(where: { $0.year > 0 })?.year ?? 0
        year = representativeYear > 0 ? String(representativeYear) : ""
        isExplicit = album.songs.contains { $0.explicitRating > 0 }
        artworkData = initialArtworkData
    }

    private func saveChanges() {
        let trimmedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedYear = Int(trimmedYear) ?? 0
        onSave(artist, albumName, genre, resolvedYear, artworkData, isExplicit ? 1 : 0)
        isPresented = false
    }
}
