import SwiftUI

/// 设置窗口：「网页」页看地址、改名称；「删除历史」页恢复或彻底删除。
struct SettingsView: View {
    @ObservedObject var store: Store
    @State private var tab = Tab.links

    private enum Tab { case links, history }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("网页").tag(Tab.links)
                Text("删除历史").tag(Tab.history)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.vertical, 12)

            Divider()

            // 内容区撑满剩余高度，空列表时切换按钮也留在顶部。
            Group {
                switch tab {
                case .links: LinksTab(store: store)
                case .history: HistoryTab(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct LinksTab: View {
    @ObservedObject var store: Store

    var body: some View {
        if store.links.isEmpty {
            ContentUnavailableView("还没有保存的网页", systemImage: "bookmark",
                                   description: Text("把网页地址拖到菜单栏图标上即可保存"))
        } else {
            List(store.links) { link in
                LinkRow(link: link, store: store)
            }
            .listStyle(.inset)
        }
    }
}

/// 悬停时右侧出现改名和删除；改名时回车保存、Esc 取消，名称清空则恢复网页标题。
private struct LinkRow: View {
    let link: Link
    @ObservedObject var store: Store
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    TextField(link.title.isEmpty ? "名称" : link.title, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand { editing = false }
                        .onChange(of: focused) { if !focused && editing { commit() } }
                } else {
                    Text(link.displayName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onTapGesture(count: 2, perform: beginEditing)
                }
                AddressText(url: link.url)
            }
            Spacer(minLength: 0)
            if !editing {
                HStack(spacing: 4) {
                    RowButton(symbol: "pencil", help: "改名", action: beginEditing)
                    RowButton(symbol: "trash", help: "删除，会移到删除历史") { store.remove(url: link.url) }
                }
                .opacity(hovering ? 1 : 0)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private func beginEditing() {
        draft = link.displayName
        editing = true
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        store.rename(url: link.url, to: draft)
        editing = false
    }
}

private struct HistoryTab: View {
    @ObservedObject var store: Store
    @State private var confirmingClear = false

    var body: some View {
        if store.history.isEmpty {
            ContentUnavailableView("没有删除过的网页", systemImage: "clock.arrow.circlepath")
        } else {
            VStack(spacing: 0) {
                List(store.history) { link in
                    HistoryRow(link: link, store: store)
                }
                .listStyle(.inset)

                Divider()
                HStack {
                    Spacer()
                    Button("清空删除历史") { confirmingClear = true }
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .confirmationDialog("清空全部删除历史？清空后无法恢复。", isPresented: $confirmingClear) {
                Button("清空", role: .destructive) { store.clearHistory() }
            }
        }
    }
}

private struct HistoryRow: View {
    let link: Link
    @ObservedObject var store: Store
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.displayName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                AddressText(url: link.url)
            }
            Spacer(minLength: 0)
            if hovering {
                HStack(spacing: 4) {
                    RowButton(symbol: "arrow.uturn.backward", help: "恢复到列表") { store.restore(url: link.url) }
                    RowButton(symbol: "xmark", help: "从删除历史里彻底删除") { store.purge(url: link.url) }
                }
            } else if let removed = link.removed {
                Text(removed, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct RowButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

private struct AddressText: View {
    let url: String

    var body: some View {
        Text(url)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .textSelection(.enabled)
            .help(url)
    }
}
