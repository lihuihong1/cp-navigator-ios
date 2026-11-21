import SwiftUI

/// 查询哪些平台（多选）。对应 Android 版的「平台 6/6」对话框。
struct SourcesSheet: View {
    @EnvironmentObject private var store: ContestStore
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<OJ> = []

    private var allSelected: Bool { selection.count == OJ.allCases.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selection = allSelected ? [] : Set(OJ.allCases)
                    } label: {
                        HStack {
                            Text("全选")
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if allSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    ForEach(OJ.allCases) { oj in
                        Button {
                            toggle(oj)
                        } label: {
                            HStack(spacing: 10) {
                                LogoView(oj: oj, size: 24)
                                Text(oj.name)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                if selection.contains(oj) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("至少选择一个平台。改动后需要重新「查询」。")
                }
            }
            .navigationTitle("查询哪些平台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        store.setEnabled(selection)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .onAppear {
            selection = store.enabled
        }
    }

    private func toggle(_ oj: OJ) {
        if selection.contains(oj) {
            selection.remove(oj)
        } else {
            selection.insert(oj)
        }
    }
}