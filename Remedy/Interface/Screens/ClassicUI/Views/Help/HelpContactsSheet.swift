//
//  HelpContactsSheet.swift
//  Remedy
//
//  classic help contacts (screen 58): up to 3 people, picked from Contacts without the Contacts permission
//

import SwiftUI
import SwiftData
import ContactsUI

// add or change who the help screen calls, or pick from contacts
struct HelpContactsSheet: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // UI only the picker, and the contact being typed or changed
    @State private var isPicking = false
    @State private var editing: ContactDraft?

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.contactRows) { row in
                        Button { editing = ContactDraft(contact: row.contact) } label: {
                            ListRow(symbol: row.contact.role == .family ? "person.crop.circle" : "phone.fill",
                                    title: row.name, subtitle: viewModel.editSubtitle(row))
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text(viewModel.contactsFooter).font(.footnote).foregroundStyle(Color.ink2)
                }
                Section {
                    Button { isPicking = true } label: {
                        ListRow(symbol: "person.crop.circle", title: HelpViewModel.chooseContact, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    Button { editing = ContactDraft(contact: nil) } label: {
                        ListRow(symbol: "plus", title: HelpViewModel.typeContact, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text(HelpViewModel.contactsFooter2).font(.footnote).foregroundStyle(Color.ink2)
                }
                .disabled(!viewModel.canAddContact)
            }
            .remedyList()
            .navigationTitle(HelpViewModel.contactsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $isPicking) {
                ContactPicker { name, phone in
                    isPicking = false
                    guard let plan = plans.first, let name else { return }
                    ContactActions.add(name: name, phone: phone ?? "", to: plan, in: context)
                }
                .ignoresSafeArea()
            }
            .sheet(item: $editing) { draft in
                ContactEditSheet(draft: draft, plan: plans.first)
            }
        }
    }
}

// the words of a contact while it is typed
struct ContactDraft: Identifiable {
    let id = UUID()
    let contact: CareContact?
}

// type or change one contact (104)
struct ContactEditSheet: View {
    let draft: ContactDraft
    let plan: CarePlan?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var isPicking = false
    @State private var asksDelete = false

    var body: some View {
        let savedName = draft.contact?.name ?? ""
        NavigationStack {
            List {
                Section {
                    field(HelpViewModel.nameLabel, text: $name)
                        .textContentType(.name)
                    field(HelpViewModel.roleLabel, text: $role)
                    field(HelpViewModel.phoneLabel, text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                Section {
                    Button { isPicking = true } label: {
                        ListRow(symbol: "person.crop.circle", title: HelpViewModel.chooseContact, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                if let contact = draft.contact {
                    Section {
                        Button(HelpViewModel.deleteContact(savedName), role: .destructive) { asksDelete = true }
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                            .confirmationDialog(HelpViewModel.deleteAsk(savedName), isPresented: $asksDelete,
                                                titleVisibility: .visible) {
                                Button(HelpViewModel.deleteContact(savedName), role: .destructive) {
                                    ContactActions.remove(contact, in: context)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                    }
                }
            }
            .remedyList()
            .navigationTitle(draft.contact == nil ? HelpViewModel.newContactTitle
                             : (savedName.isEmpty ? HelpViewModel.contactTitle : savedName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $isPicking) {
                // the picked contact fills the fields, nothing is saved until Save
                ContactPicker { pickedName, pickedPhone in
                    isPicking = false
                    if let pickedName { name = pickedName }
                    if let pickedPhone { phone = pickedPhone }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            name = draft.contact?.name ?? ""
            role = draft.contact?.detail ?? ""
            phone = draft.contact.map { PhoneFormat.text($0.phone) } ?? ""
        }
        .presentationDetents([.large])
    }

    // a grey label then the value, like contacts
    private func field(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .foregroundStyle(Color.ink2)
                .frame(width: 70, alignment: .leading)
            TextField(label, text: text)
        }
        .frame(minHeight: Spacing.minTarget)
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if let contact = draft.contact {
            ContactActions.update(contact, name: cleanName, phone: cleanPhone, detail: cleanRole, in: context)
        } else if let plan {
            ContactActions.add(name: cleanName, phone: cleanPhone, detail: cleanRole, to: plan, in: context)
        }
    }
}

// the system contact picker, it hands back one contact and needs no Contacts permission
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (String?, String?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let host = PickerHost()
        host.onPick = onPick
        return host
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    // hosts apple's contact picker
    final class PickerHost: UIViewController, CNContactPickerDelegate {
        var onPick: (String?, String?) -> Void = { _, _ in }
        private var didShow = false

        // shows apple's contact picker once, when the host appears
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !didShow else { return }
            didShow = true
            let picker = CNContactPickerViewController()
            picker.delegate = self
            picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
            present(picker, animated: true)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            onPick(name, contact.phoneNumbers.first?.value.stringValue)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPick(nil, nil)
        }
    }
}
