import Foundation
import HSRProtocol

let decoder = JSONDecoder()
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
while let line = readLine() {
  let envelope = try decoder.decode(ProtocolEnvelope.self, from: Data(line.utf8))
  let data = try encoder.encode(envelope)
  print(String(decoding: data, as: UTF8.self))
}
