import Foundation
import FoundationModels

struct SendFaxTool: Tool {
    let name = "sendFax"
    let description = "发送传真"

    let fax: FaxService

    @Generable
    struct Args {
        var documentId: String
        var faxNumber: String
    }

    @Generable
    struct Output {
        var faxId: String
        var status: String
        var price: Double
    }

    func call(arguments: Args) async throws -> Output {
        let result = try await fax.send(
            documentId: arguments.documentId,
            faxNumber: arguments.faxNumber
        )

        return Output(
            faxId: result.faxId,
            status: result.status,
            price: result.price
        )
    }
}
