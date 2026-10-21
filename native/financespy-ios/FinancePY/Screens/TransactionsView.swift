import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \AccountEntity.name)
    private var accounts: [AccountEntity]

    @Query(sort: \EntryEntity.date, order: .reverse)
    private var entries: [EntryEntity]

    @State private var selectedAccountId: String = "ALL"
    @State private var showingCreate = false
    @State private var editingEntry: EntryEntity?
    @State private var entryPendingDelete: EntryEntity?
    @State private var deleteError: String?

    private var filteredEntries: [EntryEntity] {
        if selectedAccountId == "ALL" {
            return entries
        } else {
            return entries.filter { $0.accountId == selectedAccountId }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Filter Picker
                Picker("Cuenta", selection: $selectedAccountId) {
                    Text("Todas las cuentas").tag("ALL")
                    ForEach(accounts) { account in
                        Text(account.name).tag(account.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                .padding(.top, 8)

                if filteredEntries.isEmpty {
                    Spacer()
                    Text("No hay transacciones guardadas.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.body)
                                    .fontWeight(.medium)

                                HStack(spacing: 8) {
                                    if let accountName = accountName(for: entry.accountId) {
                                        Text(accountName)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }

                                    if let cat = entry.transaction?.categoryName {
                                        Text(cat)
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                    }

                                    Text(Formatters.formatDate(entry.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            let signedCents = entry.transaction?.signedAmountCents ?? entry.amountCents
                            Text(formatCents(signedCents, currency: entry.currency))
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(signedCents < 0 ? .red : .primary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingEntry = entry }
                        .accessibilityAddTraits(.isButton)
                        .swipeActions(edge: .trailing) {
                            Button {
                                entryPendingDelete = entry
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transacciones")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nueva transacción")
                }
            }
            .sheet(isPresented: $showingCreate) {
                TransactionFormView()
            }
            .sheet(item: $editingEntry) { entry in
                TransactionFormView(transactionToEdit: entry)
            }
            .confirmationDialog(
                "¿Eliminar transacción?",
                isPresented: Binding(get: { entryPendingDelete != nil }, set: { if !$0 { entryPendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: entryPendingDelete
            ) { entry in
                Button("Eliminar", role: .destructive) {
                    Task { await delete(entry) }
                }
                Button("Cancelar", role: .cancel) {}
            } message: { entry in
                Text("\(entry.name) se eliminará de forma permanente.")
            }
            .alert("No se pudo eliminar", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func delete(_ entry: EntryEntity) async {
        do {
            _ = try await FinancePyApi.shared.deleteTransaction(id: entry.transaction?.id ?? entry.id)
            modelContext.delete(entry)
            try? modelContext.save()
        } catch {
            deleteError = TransactionFormView.message(for: error)
        }
    }

    private func accountName(for accountId: String) -> String? {
        accounts.first(where: { $0.id == accountId })?.name
    }

    private func formatCents(_ cents: Int64, currency: String) -> String {
        return Formatters.formatCents(cents, currency: currency)
    }
}
