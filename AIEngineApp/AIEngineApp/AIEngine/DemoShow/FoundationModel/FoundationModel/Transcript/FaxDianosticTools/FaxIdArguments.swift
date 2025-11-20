import Foundation
import FoundationModels

// MARK: - Tool 1: 模拟后端传真状态 JSON

/// 模拟后端 “/fax/status” 接口返回的 JSON 结构
@Generable(description: "模拟 JetFax 后端返回的传真状态 JSON payload")
struct FaxBackendStatusPayload {
    @Guide(description: "服务器里的传真唯一 ID")
    var faxId: String
    
    @Guide(description: "整体状态，例如 pending / delivered / failed")
    var status: String
    
    @Guide(description: "可选的错误码，例如 INVALID_NUMBER_FORMAT")
    var errorCode: String?
    
    @Guide(description: "人类可读的错误描述，例如运营商返回的信息")
    var errorMessage: String?
    
    @Guide(description: "使用的传真网关/运营商，例如 DemoCarrier-US-East")
    var gateway: String
    
    @Guide(description: "最后一次状态更新时间（ISO8601 字符串）")
    var lastUpdatedAt: String
}

struct FetchFaxStatusTool: Tool {
    let name = "fetchFaxStatus"
    let description = "根据 faxId 查询（模拟）后端传真状态 JSON，用于诊断发送问题。"
    
    @Generable(description: "查询传真状态所需的参数")
    struct Arguments {
        @Guide(description: "要查询的传真 ID，例如 FAX-DEMO-001")
        var faxId: String
    }
    
    func call(arguments: Arguments) async throws -> FaxBackendStatusPayload {
        let now = ISO8601DateFormatter().string(from: Date())
        
        // 简单模拟几种典型情况，实际可以替换为真实网络请求
        if arguments.faxId.isEmpty || arguments.faxId == "FAX-DEMO-001" {
            // 典型“已送达”案例
            return FaxBackendStatusPayload(
                faxId: arguments.faxId.isEmpty ? "FAX-DEMO-001" : arguments.faxId,
                status: "delivered",
                errorCode: nil,
                errorMessage: nil,
                gateway: "DemoCarrier-US-East",
                lastUpdatedAt: now
            )
        } else if arguments.faxId.uppercased().contains("INVALID") {
            // 号码格式错误
            return FaxBackendStatusPayload(
                faxId: arguments.faxId,
                status: "failed",
                errorCode: "INVALID_NUMBER_FORMAT",
                errorMessage: "The destination number is not a valid fax number.",
                gateway: "DemoCarrier-US-West",
                lastUpdatedAt: now
            )
        } else if arguments.faxId.uppercased().contains("TIMEOUT") {
            // 网络/重试超时
            return FaxBackendStatusPayload(
                faxId: arguments.faxId,
                status: "failed",
                errorCode: "GATEWAY_TIMEOUT",
                errorMessage: "All retry attempts expired before the remote fax machine answered.",
                gateway: "DemoCarrier-EU",
                lastUpdatedAt: now
            )
        } else {
            return FaxBackendStatusPayload(
                faxId: arguments.faxId,
                status: "pending",
                errorCode: nil,
                errorMessage: "Fax is queued on the carrier side, waiting for the next retry window.",
                gateway: "DemoCarrier-US-East",
                lastUpdatedAt: now
            )
        }
    }
}

// MARK: - Tool 2: 模拟后端计费 JSON

/// 模拟后端 “/billing/fax” 接口返回的计费信息
@Generable(description: "模拟 JetFax 后端返回的计费信息 JSON payload")
struct FaxBillingInfoPayload {
    @Guide(description: "计费状态，例如 charged / refunded / free")
    var status: String
    
    @Guide(description: "本次传真计费金额，单位货币由 currency 字段决定")
    var amount: Double
    
    @Guide(description: "货币代码，例如 USD、CAD")
    var currency: String
    
    @Guide(description: "对应的内购 / 订阅产品 ID")
    var productId: String
    
    @Guide(description: "是否使用了免费页 / 赠送页")
    var usedFreeQuota: Bool
}

struct FetchBillingInfoTool: Tool {
    let name = "fetchBillingInfo"
    let description = "根据 faxId 查询（模拟）计费信息，例如是否已经扣费、金额多少。"
    
    @Generable(description: "查询计费信息的参数")
    struct Arguments {
        @Guide(description: "要查询的传真 ID，例如 FAX-DEMO-001")
        var faxId: String
    }
    
    func call(arguments: Arguments) async throws -> FaxBillingInfoPayload {
        // 根据 faxId 做一些简单分支，模拟不同业务场景
        if arguments.faxId.uppercased().contains("FREE") {
            return FaxBillingInfoPayload(
                status: "free",
                amount: 0.0,
                currency: "USD",
                productId: "jetfax.free.quota",
                usedFreeQuota: true
            )
        } else if arguments.faxId.uppercased().contains("REFUND") {
            return FaxBillingInfoPayload(
                status: "refunded",
                amount: 2.99,
                currency: "USD",
                productId: "jetfax.one_time_20",
                usedFreeQuota: false
            )
        } else {
            // 默认：已正常扣费
            return FaxBillingInfoPayload(
                status: "charged",
                amount: 2.99,
                currency: "USD",
                productId: "jetfax.one_time_20",
                usedFreeQuota: false
            )
        }
    }
}
