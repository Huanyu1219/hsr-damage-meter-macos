import LiveDomain
import SwiftUI

struct CharacterDamageTable: View {
  let snapshot: LiveSnapshot
  @Binding var selection: UInt32?
  @State private var sortBy = "伤害"
  @State private var ascending = false

  private var characters: [LiveCharacter] {
    let key: KeyPathComparator<LiveCharacter>
    switch sortBy {
    case "角色": key = KeyPathComparator(\.name, order: ascending ? .forward : .reverse)
    default: key = KeyPathComparator(\.damage, order: ascending ? .forward : .reverse)
    }
    return snapshot.characters.sorted(using: [key, KeyPathComparator(\.id)])
  }

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
      GridRow {
        heading("角色").frame(width: 118, alignment: .leading)
        heading("伤害").gridColumnAlignment(.trailing)
        heading("全队占比").gridColumnAlignment(.trailing)
        heading("DPS").frame(maxWidth: .infinity, alignment: .trailing).gridColumnAlignment(
          .trailing)
      }.padding(.bottom, 10)
      Divider().gridCellUnsizedAxes(.horizontal)
      ForEach(characters) { character in
        GridRow {
          Button {
            selection = selection == character.id ? nil : character.id
          } label: {
            HStack(spacing: 8) {
              CharacterPortrait(id: character.id, name: character.name, size: 28)
              Text(character.name).fontWeight(.medium).lineLimit(1)
            }.frame(width: 118, alignment: .leading).contentShape(Rectangle())
          }.buttonStyle(.plain)
            .foregroundStyle(selection == character.id ? Color.accentColor : .primary)
            .accessibilityAddTraits(selection == character.id ? .isSelected : [])
          numeric(DamageFormatting.compact(character.damage), precise: character.damage.description)
          numeric(
            DamageFormatting.ratio(character.damage, to: snapshot.total).formatted(
              .percent.precision(.fractionLength(1))))
          numeric(DamageFormatting.dps(character.damage, elapsed: snapshot.elapsed))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(.vertical, 6)
      }
    }.font(.subheadline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(
        Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: AppRadius.card))
  }

  private func heading(_ title: String) -> some View {
    Button {
      if sortBy == title {
        ascending.toggle()
      } else {
        sortBy = title
        ascending = title == "角色"
      }
    } label: {
      HStack(spacing: 3) {
        Text(title)
        if sortBy == title {
          Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 8))
        }
      }.foregroundStyle(.secondary).lineLimit(1)
    }.buttonStyle(.plain)
  }

  private func numeric(_ value: String, precise: String = "") -> some View {
    Text(value).monospacedDigit().lineLimit(1).frame(width: 82, alignment: .trailing)
      .help(precise.isEmpty ? value : precise)
  }
}

struct DamageTypeTable: View {
  let snapshot: LiveSnapshot
  let selected: LiveCharacter?
  @State private var expanded = true

  private var rows: [DamageCategory] {
    DamageBreakdown.categories(selected.map { [$0] } ?? snapshot.characters)
  }
  private var denominator: Decimal { selected?.damage ?? snapshot.total }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        expanded.toggle()
      } label: {
        HStack {
          Text("伤害类型 · \(rows.count) 类").font(.headline)
          Spacer()
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.caption).foregroundStyle(.secondary)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain)
      if expanded {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
          Text(selected.map { "\($0.name)" } ?? "全队")
            .font(.caption).foregroundStyle(.secondary)
          Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: AppSpacing.md) {
            GridRow {
              Text("分类").frame(maxWidth: .infinity, alignment: .leading)
              Text("伤害").frame(maxWidth: .infinity, alignment: .trailing)
                .gridColumnAlignment(.trailing)
              if selected != nil {
                Text("角色占比").frame(maxWidth: .infinity, alignment: .trailing).gridColumnAlignment(
                  .trailing)
              }
              Text("全队占比").frame(maxWidth: .infinity, alignment: .trailing).gridColumnAlignment(
                .trailing)
            }.font(.caption).foregroundStyle(.secondary)
            Divider().gridCellUnsizedAxes(.horizontal)
            ForEach(rows) { row in
              GridRow {
                Text(row.label).lineLimit(2).help(row.id)
                Text(DamageFormatting.compact(row.damage)).help(row.damage.description)
                if selected != nil {
                  Text(
                    DamageFormatting.ratio(row.damage, to: denominator).formatted(
                      .percent.precision(.fractionLength(1))))
                }
                Text(
                  DamageFormatting.ratio(row.damage, to: snapshot.total).formatted(
                    .percent.precision(.fractionLength(1))))
              }.font(.subheadline).monospacedDigit()
            }
          }.frame(maxWidth: .infinity, alignment: .leading)

        }.padding(.top, AppSpacing.md)
      }
    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
      .background(
        Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: AppRadius.card))
  }
}
