*** Settings ***
Library           RPA.Browser.Selenium    auto_close=${FALSE}
Library           RPA.PDF
Library           RPA.FileSystem
Library           RPA.Archive
Library           RPA.HTTP
Library           RPA.Excel.Files
Library           RPA.Tables

Suite Teardown    Close All Browsers

*** Variables ***
${ORDER_SITE}             https://robotsparebinindustries.com/#/robot-order
${OUTPUT_DIR}             ${CURDIR}${/}output
${ARCHIVE_NAME}           RobotOrders
${CSV_URL}                https://robotsparebinindustries.com/orders.csv
${GLOBAL_RETRY_AMOUNT}    3
${GLOBAL_RETRY_INTERVAL}  5s
${locator}    id:preview

*** Tasks ***
Order Robots from RobotSpareBin Industries Inc
    Open Robot Order Website
    ${orders}=    Get Orders File
    FOR    ${order}    IN    @{orders}
        ${order_number}=    Set Variable    ${order["Order number"]}
        Log    Processing order ${order_number}
        Run Keyword And Continue On Failure    Close Annoying Modal
        Run Keyword And Continue On Failure    Fill The Form    ${order}
        Run Keyword And Continue On Failure    Wait For Element To Be Ready    id:preview
        Run Keyword And Continue On Failure    Click Button    id:preview
        Run Keyword And Continue On Failure    Click Preview And Continue On Error    ${order_number}
        ${screenshot}=    Run Keyword And Continue On Failure    Take Screenshot Of The Robot    ${order_number}
        Run Keyword And Continue On Failure    Submit Robot Order
        ${pdf_path}=    Run Keyword And Continue On Failure    Store The Receipt As A PDF File    ${order_number}
        Run Keyword And Continue On Failure
        ...    Embed The Robot Screenshot To The Receipt PDF File
        ...    ${screenshot}
        ...    ${pdf_path}
        # This next line will only be executed if it's not the last order
        Run Keyword And Continue On Failure    Click Button    id:order-another
    END

END FOR
    # The following line archives all the PDFs after all orders have been processed
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIR}${/}PDFs.zip
    Run Keyword And Continue On Failure    Archive Folder With Zip    ${OUTPUT_DIR}${/}PDF    ${zip_file_name}

*** Keywords ***
Open Robot Order Website
    Open Available Browser    ${ORDER_SITE}
    Maximize Browser Window

Get Orders File
    Download    ${CSV_URL}    ${OUTPUT_DIR}${/}orders.csv    overwrite=True
    ${orders}=    Read Table From CSV    ${OUTPUT_DIR}${/}orders.csv    header=True
    Log    Orders file read successfully.
    [Return]    ${orders}

Close Annoying Modal
    Wait Until Page Contains Element    //div[contains(@class, 'modal')]    timeout=10s
    Click Button    //button[contains(@class, 'btn-danger')]

Fill The Form
    [Arguments]    ${order}
    Select From List By Value    id=head    ${order["Head"]}
    Select Radio Button    body    ${order["Body"]}
    Input Text    //input[@placeholder="Enter the part number for the legs"]    ${order["Legs"]}
    Input Text    xpath://input[@name="address"]    ${order["Address"]}

Wait For Element To Be Ready
    [Arguments]    ${locator}    ${timeout}=30s
    Wait Until Page Contains Element    ${locator}    timeout=${timeout}
    Wait Until Element Is Visible    ${locator}    timeout=${timeout}

Click Preview And Continue On Error
    [Arguments]    ${order_num}
    ${status}    ${value}=    Run Keyword And Ignore Error    Click Button    id=preview
    [Return]    ${status}        

*** Keywords ***
Retry Keyword
    [Arguments]    ${keyword}
    FOR    ${retry}    IN RANGE    ${GLOBAL_RETRY_AMOUNT}
        ${status}=    Run Keyword And Ignore Error    ${keyword}
        Run Keyword Unless    '${status}' == 'PASS'    Sleep    ${GLOBAL_RETRY_INTERVAL}
        Exit For Loop If    '${status}' == 'PASS'
    END

  

Take Screenshot Of The Robot
    [Arguments]    ${order_num}
    ${screenshot_path}=    Set Variable    ${OUTPUT_DIR}${/}output${/}${order_num}.png
    Wait Until Element Is Visible    id:robot-preview-image    timeout=180s
    Capture Element Screenshot    id:robot-preview-image    ${screenshot_path}
    [Return]    ${screenshot_path}

*** Keyword ***
Submit Robot Order
    Wait Until Element Is Visible    id=order    timeout=60s
    Scroll Element Into View    id=order
    Sleep    5s
    Capture Page Screenshot
    Run Keyword And Ignore Error    Click Button    id=order
    Wait Until Element Is Visible    id=receipt    timeout=180s

Attempt To Store Receipt As PDF
    [Arguments]    ${order_num}
    ${status}    ${pdf_path}=    Run Keyword And Ignore Error    Store The Receipt As A PDF File    ${order_num}
    IF    '${status}' != 'PASS'
        Log    Failed to store the receipt as a PDF: ${pdf_path}
    END
    RETURN    ${pdf_path}

Wait For Receipt To Appear
    Wait Until Element Is Visible    id:receipt    60s

Store The Receipt As A PDF File
    [Arguments]    ${order_number}
    Wait Until Element Is Visible    id:receipt    180s
    Wait Until Page Contains Element    id:receipt    timeout=60s
    ${Receipt_in_html}=    Get Element Attribute    id=receipt    outerHTML
    Create Directory    ${OUTPUT_DIR}${/}PDF
    Html To Pdf    ${Receipt_in_html}    ${OUTPUT_DIR}${/}PDF${/}${order_number}.pdf
    ${pdf_path}=    Set Variable    ${OUTPUT_DIR}${/}PDF${/}${order_number}.pdf
    RETURN    ${pdf_path}

*** Keywords ***
Embed the Robot Screenshot To The Receipt PDF File
    [Arguments]    ${screenshot}    ${pdf_path}
    Open PDF    ${pdf_path}
    ${screenshot_list}=    Create List    ${screenshot}
    Add Watermark Image To Pdf    image_path=${screenshot}    output_path=${pdf_path}
    Add Files To PDF    files=${screenshot_list}    target_document=${pdf_path}    append=True
    

Package The Documents For Sharing
    Archive Folder With Zip    folder=${OUTPUT_DIR}    archive_name=${ARCHIVE_NAME}    recursive=True include=*.pdf
