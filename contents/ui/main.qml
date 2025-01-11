import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import Qt.labs.platform 1.0 as Platform

ApplicationWindow {
    id: root

    visible: true
    width: 350
    height: 500
    title: "ChatQT"

    property string parentMessageId: ''
    property string modelsComboboxCurrentValue: '';    
    property var listModelController;
    property var promptArray: [];
    property var modelsArray: [];
    property bool isLoading: false
    property bool hasLocalModel: false;
    property bool disableAutoScroll: false;

    function parseTextToComboBox(text) {
        return text
            .replace(/-/g, ' ')
            .replace(/:(.+)/, ' ($1)')
            .split(' ')
            .map(word => {
                if (word.startsWith('(')) {
                    return word.charAt(0) + word.charAt(1).toUpperCase() + word.slice(2);
                }
                return word.charAt(0).toUpperCase() + word.slice(1);
            })
            .join(' ');
    }

    function request(messageField, listModel, scrollView, prompt) {
        messageField.text = '';

        listModel.append({
            "name": "User",
            "number": prompt
        });

        promptArray.push({ "role": "user", "content": prompt, "images": [] });

        isLoading = true;

        if (!disableAutoScroll && scrollView.ScrollBar) {
            scrollView.ScrollBar.vertical.position = 1;
        }

        const oldLength = listModel.count;
        const url = 'http://127.0.0.1:11434/api/chat';
        const data = JSON.stringify({
            "model": modelsComboboxCurrentValue,
            "keep_alive": "5m",
            "options": {},
            "messages": promptArray
        });
        
        let xhr = new XMLHttpRequest();

        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/json');
        xhr.onreadystatechange = function() {
            const objects = xhr.responseText.split('\n');
            let text = '';

            objects.forEach((object, index) => {
                const parsedObject = JSON.parse(object);
                text = text + parsedObject?.message?.content;

                if (index === 0 ) {
                    text = text.trim();
                }

                if (!disableAutoScroll && scrollView.ScrollBar) {
                    scrollView.ScrollBar.vertical.position = 1 - scrollView.ScrollBar.vertical.size;
                }

                if (listModel.count === oldLength) {
                    listModel.append({
                        "name": "Assistant",
                        "number": text
                    });
                } else {
                    const lastValue = listModel.get(oldLength);

                    lastValue.number = text;
                }
            });
        };

        xhr.onload = function() {
            const lastValue = listModel.get(oldLength);

            isLoading = false;

            promptArray.push({ "role": "assistant", "content": lastValue.number, "images": [] });
        };

        xhr.send(data);
    }

    function getModels() {
        const url = 'http://127.0.0.1:11434/api/tags';

        let xhr = new XMLHttpRequest();

        xhr.open('GET', url);
        xhr.setRequestHeader('Content-Type', 'application/json');

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    const objects = JSON.parse(xhr.responseText).models;
                    
                    const models = objects.map(object => object.model);

                    if (models.length) {
                        hasLocalModel = true;

                        modelsComboboxCurrentValue = models[0];

                        modelsArray = models.map(model => ({ text: parseTextToComboBox(model), value: model }));
                    }
                } else {
                    console.error('Erro na requisição:', xhr.status, xhr.statusText);
                }
            }
        };

        xhr.send();
    }

    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")
            MenuItem {
                text: qsTr("&Quit")
                onTriggered: Qt.quit()
            }
            MenuItem {
                text: qsTr("&Keep Open")
            checkable: true
                checked: root.visibility
                onTriggered: root.visibility = checked
            }
            MenuItem {
                text: qsTr("&Clear Chat")
            onTriggered: {
                listModelController.clear();
                promptArray = [];
            }
            }
            MenuItem {
                text: qsTr("&Disable Auto Scroll")
            checkable: true
            checked: disableAutoScroll
            onTriggered: disableAutoScroll = !disableAutoScroll
        }
        }
    }

    ColumnLayout {
        anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

        RowLayout {
            visible: hasLocalModel
            width: parent.width

            PlasmaComponents.ComboBox {
                id: modelsCombobox
                enabled: hasLocalModel && !isLoading
                hoverEnabled: hasLocalModel && !isLoading
            Layout.fillWidth: true
                model: modelsArray.map(model => model.text)
            
                onActivated: {
                    modelsComboboxCurrentValue = modelsArray.find(model => model.text === modelsCombobox.currentText).value;
                    listModelController.clear();
                }

                Component.onCompleted: getModels()
            }
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 150
            clip: true
            
            ListView {
                id: listView
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                Layout.fillHeight: true

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.largeSpacing * 4)
                    visible: listView.count === 0
                    text: hasLocalModel ? i18n("I am waiting for your questions...") : i18n("No local model found.\nPlease install some first.\n\nIf you need help, check Ollama documentation.")
        }

                model: ListModel {
                    id: listModel

                    Component.onCompleted: {
                        listModelController = listModel;
    }
}

                delegate: Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    implicitHeight: 24 + textMessage.implicitHeight

                    contentItem: TextEdit {
                        id: textMessage
                        topPadding: 8
                        readOnly: true
                        wrapMode: Text.WordWrap
                        text: number
                        color: name === "User" ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                        selectByMouse: true

                        PlasmaComponents.Button {
                            anchors.right: parent.right
                            icon.name: "edit-copy-symbolic"
                            text: i18n("Copy")
                            display: PlasmaComponents.AbstractButton.IconOnly
                            visible: hoverHandler.hovered
                            
                            onClicked: {
                                textMessage.selectAll();
                                textMessage.copy();
                                textMessage.deselect();
                            }

                            PlasmaComponents.ToolTip.text: text
                            PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents.ToolTip.visible: hovered
                        }

                        HoverHandler { id: hoverHandler }
                    }
                }
            }
        }

        TextArea {
            id: messageField
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            enabled: hasLocalModel && !isLoading
            hoverEnabled: hasLocalModel && !isLoading
            placeholderText: i18n("Type here what you want to ask...")
            wrapMode: TextArea.Wrap

            Keys.onReturnPressed: {
                if (event.modifiers & Qt.ControlModifier) {
                    request(messageField, listModel, scrollView, messageField.text);
                } else {
                    event.accepted = false;
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                running: isLoading
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: i18n("Send")
            hoverEnabled: hasLocalModel && !isLoading
            enabled: hasLocalModel && !isLoading
            visible: hasLocalModel

            onClicked: request(messageField, listModel, scrollView, messageField.text);
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: i18n("Refresh models list")
            visible: !hasLocalModel

            onClicked: getModels()
        }
    }
}