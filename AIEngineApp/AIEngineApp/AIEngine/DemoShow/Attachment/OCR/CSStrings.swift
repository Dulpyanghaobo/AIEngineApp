//
//  Strings.swift
//  WatermarkCamera
//
//  Created by i564407 on 2025/7/7.
//
import Foundation

final class CSStrings {
    static let shared = CSStrings()
    private init() {}

}

extension CSStrings {
    func localized(for key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

extension CSStrings {
    // Onboarding Page 1
    func onboardingTitle1() -> String {
        localized(for: "onboarding_title_1")
    }
    func onboardingSubtitle1() -> String {
        localized(for: "onboarding_subtitle_1")
    }

    // Onboarding Page 2
    func onboardingTitle2() -> String {
        localized(for: "onboarding_title_2")
    }
    func onboardingSubtitle2() -> String {
        localized(for: "onboarding_subtitle_2")
    }

    // Onboarding Page 3
    func onboardingTitle3() -> String {
        localized(for: "onboarding_title_3")
    }
    func onboardingSubtitle3() -> String {
        localized(for: "onboarding_subtitle_3")
    }

    // Onboarding Page 4
    func onboardingTitle4() -> String {
        localized(for: "onboarding_title_4")
    }
    func onboardingSubtitle4() -> String {
        localized(for: "onboarding_subtitle_4")
    }

    // Buttons
    func onboardingButtonContinue() -> String {
        localized(for: "onboarding_button_continue")
    }
    func onboardingButtonGetStarted() -> String {
        localized(for: "onboarding_button_get_started")
    }
}

extension CSStrings {
    // 首页标题
    func homeDocumentsTitle() -> String { localized(for: "home_documents_title") }

    // 选择模式
    func selectAll() -> String { localized(for: "select_all") }
    func selectedCount(_ n: Int) -> String {
        String(format: localized(for: "selected_count_fmt"), n)
    }
    func done() -> String { localized(for: "done") }

    // 空态
    func emptyNoDocuments() -> String { localized(for: "empty_no_documents") }
    func emptyScanButton() -> String { localized(for: "empty_scan_button") }

    // 重命名弹窗
    func renameTitle() -> String { localized(for: "rename_title") }
    func renamePlaceholder() -> String { localized(for: "rename_placeholder") }
    func save() -> String { localized(for: "save") }
    func cancel() -> String { localized(for: "cancel") }
    func renameMessage() -> String { localized(for: "rename_message") }

    // 长按菜单
    func menuRename() -> String { localized(for: "menu_rename") }
    func menuExport() -> String { localized(for: "menu_export") }
    func menuMove()   -> String { localized(for: "menu_move") }
    func menuSelect() -> String { localized(for: "menu_select") }
    func menuDelete() -> String { localized(for: "menu_delete") }
}

extension CSStrings {
    // Import HUD
    func importProgressTitle() -> String {
        localized(for: "import_progress_title")
    }
    func importProgressDesc() -> String {
        localized(for: "import_progress_desc")
    }

}
extension CSStrings {
    // DocumentSourceSheet – action titles
    func importScanDocumentTitle() -> String {
        localized(for: "import_scan_document_title")
    }
    func importPhotoGalleryTitle() -> String {
        localized(for: "import_photo_gallery_title")
    }
    func importFileTitle() -> String {
        localized(for: "import_file_title")
    }
}

extension CSStrings {
    // Merge Dialog
    func mergeDialogTitle() -> String {
        localized(for: "merge_dialog_title")
    }
    func mergeDialogMessage() -> String {
        localized(for: "merge_dialog_message")
    }
    func mergeDialogKeepSeparate(_ count: Int) -> String {
        String(format: localized(for: "merge_dialog_keep_separate_fmt"), count)
    }
    func mergeDialogMerge() -> String {
        localized(for: "merge_dialog_merge")
    }
}

extension CSStrings {
    // 通用
    func move() -> String { localized(for: "move") }
    func ok() -> String { localized(for: "ok") }
    func errorTitle() -> String { localized(for: "error_title") }
    // 已有 cancel() 可复用

    // MovePicker 专用
    func movePickerHeader() -> String {
        localized(for: "move_picker_header")
    }
    func movePickerItemsCount(_ n: Int) -> String {
        String(format: localized(for: "move_picker_items_count_fmt"), n)
    }
}
extension CSStrings {
    // Multi-Select Toolbar
    func createFolder() -> String { localized(for: "create_folder") }
    func exportTitle() -> String { localized(for: "export") }
    func deleteTitle() -> String { localized(for: "delete") }
}

extension CSStrings {
    // New Folder Sheet
    func folderNameTitle() -> String { localized(for: "folder_name_title") }
    func newFolderDefaultName() -> String { localized(for: "new_folder_default_name") }
    func newFolderPlaceholder() -> String { localized(for: "new_folder_placeholder") }
    func untitledName() -> String { localized(for: "untitled") }
}

extension CSStrings {
    // Defaults / naming
    func scanFilenamePrefix() -> String { localized(for: "scan_filename_prefix") } // "Scan_"

    // Errors & toasts
    func errFailedToLoadItems() -> String { localized(for: "err_failed_to_load_items") }
    func errFailedToCreateFolder() -> String { localized(for: "err_failed_to_create_folder") }
    func importCancelled() -> String { localized(for: "import_cancelled") }
    func importFailed() -> String { localized(for: "import_failed") }
    func errInvalidPDF() -> String { localized(for: "err_invalid_pdf") }
    func errFailedToPrepareExport() -> String { localized(for: "err_failed_to_prepare_export") }

    // Merge
    func mergeSelectAtLeastTwo() -> String { localized(for: "merge_select_at_least_two") }
    func mergeFailedNoPages() -> String { localized(for: "merge_failed_no_pages") }
    func mergeFailed() -> String { localized(for: "merge_failed") }

    // Success toasts with filename
    func toastImportedMergedAs(_ name: String) -> String {
        String(format: localized(for: "toast_imported_merged_as_fmt"), name)
    }
    func toastMergedAs(_ name: String) -> String {
        String(format: localized(for: "toast_merged_as_fmt"), name)
    }
}

extension CSStrings {
    // OCR Result – Buttons & A11y
    func close() -> String { localized(for: "close") }
    func shareTitle() -> String { localized(for: "share") }
    func copyAllTitle() -> String { localized(for: "copy_all") }

    // OCR Result – Toasts
    func copySuccess() -> String { localized(for: "copy_success") }
    func shareSuccess() -> String { localized(for: "share_success") }
    func shareFailed() -> String { localized(for: "share_failed") }

    // OCR Result – Export filename
    func ocrTxtDefaultName() -> String { localized(for: "ocr_txt_default_name") } // e.g. "OCR_Text"
}

extension CSStrings {
    // Settings – Titles
    func settingsTitle() -> String { localized(for: "settings_title") }              // "Settings"
    func settingsDarkMode() -> String { localized(for: "settings_dark_mode") }       // "Dark mode"
    func settingsStartWith() -> String { localized(for: "settings_start_with") }     // "Start with"
    func settingsStartWithDots() -> String { localized(for: "settings_start_with_dots") } // "Start with…"

    // Links & Sections
    func helpTitle() -> String { localized(for: "help_title") }                      // "Help"
    func privacyPolicyTitle() -> String { localized(for: "privacy_policy_title") }   // "Privacy Policy"
    func termsOfUseTitle() -> String { localized(for: "terms_of_use_title") }        // "Terms of Use"
    func tryOurAppsSection() -> String { localized(for: "try_our_apps_section") }    // "Try our apps"

    // Subscription Card
    func subCardTitle() -> String { localized(for: "sub_card_title") }               // "Scanner Pro"
    func subCardSubtitle() -> String { localized(for: "sub_card_subtitle") }         // "Unlock all features 😊"
    func getProButton() -> String { localized(for: "get_pro_button") }               // "GET PRO"
    func subscribedOnWebPrefix() -> String { localized(for: "subscribed_on_web_prefix") } // "Subscribed on the web? "
    func restoreLink() -> String { localized(for: "restore_link") }                  // "Restore"

    // Mail subject (optional)
    func supportEmailSubject() -> String { localized(for: "support_email_subject") } // "Support Request"
}

extension CSStrings {
    // Try Our App Row
    func tryOtherAppSubtitle() -> String {
        localized(for: "try_other_app_subtitle")
    }
    func openButton() -> String {
        localized(for: "open_button")
    }
    func getButton() -> String {
        localized(for: "get_button")
    }
}

extension CSStrings {
    // ExportSheetHost
    func exportPreparing() -> String { localized(for: "export_preparing") }
    func errFailedToLoadDocument() -> String { localized(for: "err_failed_to_load_document") }

    func encryptPDFTitle() -> String { localized(for: "encrypt_pdf_title") }
    func enterPasswordHint() -> String { localized(for: "enter_password_hint") }
    func upgradeButton() -> String { localized(for: "upgrade_button") }

    // Banner："%d FREE SHARES LEFT"
    func freeSharesLeft(_ count: Int) -> String {
        String(format: localized(for: "free_shares_left_fmt"), count)
    }

    // 区块标题
    func shareAsTitle() -> String { localized(for: "share_as_title") }
    func qualityTitle() -> String { localized(for: "quality_title") }
    func fileSizeTitle() -> String { localized(for: "file_size_title") }

    // 质量档位
    func qualityHigh() -> String { localized(for: "quality_high") }
    func qualityMedium() -> String { localized(for: "quality_medium") }
    func qualityLow() -> String { localized(for: "quality_low") }

    // 底部按钮
    func sendFaxButton() -> String { localized(for: "send_fax_button") }
    func shareButton() -> String { localized(for: "share_button") }
}
extension CSStrings {

    func continueButton() -> String { localized(for: "continue_button") }

    // Hero
    func paywallHeroTitle() -> String { localized(for: "paywall_hero_title") }
    func paywallHeroSubtitle() -> String { localized(for: "paywall_hero_subtitle") }

    // Trial toggle
    func trialToggleTitle() -> String { localized(for: "trial_toggle_title") }
    func trialToggleSubtitle() -> String { localized(for: "trial_toggle_subtitle") }

    // Benefits
    func benefitUnlimitedDocsTitle() -> String { localized(for: "benefit_unlimited_docs_title") }
    func benefitUnlimitedDocsSubtitle() -> String { localized(for: "benefit_unlimited_docs_subtitle") }
    func benefitOcrTitle() -> String { localized(for: "benefit_ocr_title") }
    func benefitOcrSubtitle() -> String { localized(for: "benefit_ocr_subtitle") }
    func benefitSignTitle() -> String { localized(for: "benefit_sign_title") }
    func benefitSignSubtitle() -> String { localized(for: "benefit_sign_subtitle") }
    func benefitExportTitle() -> String { localized(for: "benefit_export_title") }
    func benefitExportSubtitle() -> String { localized(for: "benefit_export_subtitle") }

    // Terms
    func termsIntro() -> String { localized(for: "terms_intro") }
    func termsOfServiceLink() -> String { localized(for: "terms_of_service_link") }
    func privacyPolicyLink() -> String { localized(for: "privacy_policy_link") }
    func andConnector() -> String { localized(for: "and_connector") }
}

extension CSStrings {
    // Plans
    func everyWeek() -> String { localized(for: "every_week") }
    func monthly() -> String { localized(for: "monthly") }
    func everyYear() -> String { localized(for: "every_year") }
    func perWeekSuffix() -> String { localized(for: "per_week_suffix") } // "/week"

    // Trial badges
    func dayFreeTrial(_ n: Int) -> String {
        String(format: localized(for: "day_free_trial_fmt"), n)
    }
    func weekFreeTrial(_ n: Int) -> String {
        String(format: localized(for: "week_free_trial_fmt"), n)
    }
    func monthFreeTrial(_ n: Int) -> String {
        String(format: localized(for: "month_free_trial_fmt"), n)
    }
    func freeTrial() -> String { localized(for: "free_trial") }

    // Promo badges
    func limitedTime() -> String { localized(for: "limited_time") }
    func savePercent(_ n: Int) -> String {
        String(format: localized(for: "save_percent_fmt"), n)
    }

    // Subscription period display
    func daily() -> String { localized(for: "daily") }
    func days(_ n: Int) -> String {
        String(format: localized(for: "days_fmt"), n)
    }
    func weekly() -> String { localized(for: "weekly") }
    func weeks(_ n: Int) -> String {
        String(format: localized(for: "weeks_fmt"), n)
    }
    func monthly1() -> String { localized(for: "monthly1") }
    func months(_ n: Int) -> String {
        String(format: localized(for: "months_fmt"), n)
    }
    func yearly() -> String { localized(for: "yearly") }
    func years(_ n: Int) -> String {
        String(format: localized(for: "years_fmt"), n)
    }
    func subscription() -> String { localized(for: "subscription") }
}
extension CSStrings {
    // Crop
    func cropNavTitle() -> String { localized(for: "crop_nav_title") }              // "Crop"
    func cropActionAuto() -> String { localized(for: "crop_action_auto") }          // "Crop"（自动裁剪按钮文案，保持与现有一致）
    func reset() -> String { localized(for: "reset") }                               // "Reset"

    // Page Counter: "%d / %d"
    func cropPageCounter(_ current: Int, _ total: Int) -> String {
        String(format: localized(for: "crop_page_counter_fmt"), current, total)
    }

}

extension CSStrings {
    func loadingPdf() -> String { localized(for: "loading_pdf") }
}

extension CSStrings {
    // Document Edit
    func pageSizeLabel() -> String { localized(for: "page_size_label") }   // "Page size"
    func pageCounter(_ current: Int, _ total: Int) -> String {
        String(format: localized(for: "page_counter_fmt"), current, total)
    }

    func filtersTitle() -> String { localized(for: "filters_title") }      // "Filters"
    func rotateTitle() -> String { localized(for: "rotate_title") }        // "Rotate"
    func applyingFilter() -> String { localized(for: "applying_filter") }  // "Applying filter…"
}

extension CSStrings {
    // Busy / Saving / Adding / Deleting
    func savingChangesEllipsis() -> String { localized(for: "saving_changes_ellipsis") } // "Saving changes…"
    func deletingEllipsis() -> String { localized(for: "deleting_ellipsis") }            // "Deleting…"
    func addingPageEllipsis() -> String { localized(for: "adding_page_ellipsis") }       // "Adding page…"

    // OCR scanning overlay
    func ocrRecognizingTitle() -> String { localized(for: "ocr_recognizing_title") }     // "Recognizing text…"
    func ocrRecognizingDesc() -> String { localized(for: "ocr_recognizing_desc") }       // "Please wait until the text recognition is complete.\nThis may take some time."

    // Grid / selection
    func deselectAll() -> String { localized(for: "deselect_all") }                      // "Deselect all"
    func selectTitle() -> String { localized(for: "select_title") }                      // "Select"
    func pagesTitle() -> String { localized(for: "pages_title") }                        // "Pages"
    func pagesCount(_ n: Int) -> String { String(format: localized(for: "pages_count_fmt"), n) } // "%d pages"
    func selectedLower() -> String { localized(for: "selected_lower") }                  // "selected"

    func addTitle() -> String { localized(for: "add_title") }        // "Add"
    func signTitle() -> String { localized(for: "sign_title") }      // "Sign"
    func editTitle() -> String { localized(for: "edit_title") }      // "Edit"
    func addPagesTitle() -> String { localized(for: "add_pages_title") } // "Add pages"
    // Rename alert (已有 renameTitle / renamePlaceholder / save / cancel，可复用)
    func renameExtLocked(_ ext: String) -> String {
        // ext 传入 "pdf" 这样的不带点的小写
        String(format: localized(for: "rename_ext_locked_fmt"), ext)
    }
}

extension CSStrings {
    // Page Size – Names
    func pageSizeOriginal() -> String { localized(for: "page_size_original") }          // "Original"
    func pageSizeA3() -> String { localized(for: "page_size_a3") }                      // "A3"
    func pageSizeA4() -> String { localized(for: "page_size_a4") }                      // "A4"
    func pageSizeA5() -> String { localized(for: "page_size_a5") }                      // "A5"
    func pageSizeUSLetter() -> String { localized(for: "page_size_us_letter") }         // "US Letter"
    func pageSizeUSHalf() -> String { localized(for: "page_size_us_half") }             // "US Half"
    func pageSizeUSLegal() -> String { localized(for: "page_size_us_legal") }           // "US Legal"
    func pageSizeBusinessCard() -> String { localized(for: "page_size_business_card") } // "Business Card"
    func pageSizeIDCard() -> String { localized(for: "page_size_id_card") }             // "ID Card"

    // Page Size – Dimension: "%d×%d mm"
    func pageSizeDimensionMM(_ w: Int, _ h: Int) -> String {
        String(format: localized(for: "page_size_dimension_mm_fmt"), w, h)
    }
}

extension CSStrings {
    // Page Size Screen
    func pageSizeTitle() -> String { localized(for: "page_size_title") }      // "Page Size"
    func applyToAll() -> String { localized(for: "apply_to_all") }            // "Apply to all"
    func appliedToAll() -> String { localized(for: "applied_to_all") }        // "Applied to all"
    func esignTapToInsert() -> String { localized(for: "esign_tap_to_insert") } // "Tap where you want to insert signature"
    func signatureTitle() -> String { localized(for: "signature_title") }       // "Signature"
    func addSignatureA11y() -> String { localized(for: "add_signature_a11y") }  // "Add signature"
}

extension CSStrings {
    // Signature
    func signHereHint() -> String { localized(for: "sign_here_hint") }           // "SIGN HERE"
    func yourSignatureTitle() -> String { localized(for: "your_signature_title") } // "Your Signature"

    // Signature errors
    func signatureEmptyError() -> String { localized(for: "signature_empty_error") } // "Signature is empty"
}
