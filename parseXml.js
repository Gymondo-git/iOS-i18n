const fs = require('fs')
const readline = require('readline')
const convert = require('xml-js')

const args = process.argv.slice(2)

const options = { compact: false, spaces: 4 }

const localizableKey = value => JSON.parse(convert.xml2json(`<userDefinedRuntimeAttribute type="string" keyPath="localizableKey" value="${value}"/>`, options))
const userDefinedAttrs = value => JSON.parse(convert.xml2json(`<userDefinedRuntimeAttributes><userDefinedRuntimeAttribute type="string" keyPath="localizableKey" value="${value}"/></userDefinedRuntimeAttributes>`, options))

const processElement = (node, value) => {
    if (!node.elements) {
        node.elements = []
        node.elements.push(userDefinedAttrs(value).elements[0])
    } else {
        const attrIndex = node.elements
            .findIndex(element => element.name === 'userDefinedRuntimeAttributes')
        if (attrIndex >= 0) {
            node.elements[attrIndex].elements.push(localizableKey(value).elements[0])
        } else {
            node.elements.push(userDefinedAttrs(value).elements[0])
        }
    }
}

function findNode(id, value, currentNode) {
    let i
    let result

    if (currentNode.attributes && id === currentNode.attributes.id) {
        processElement(currentNode, value)

        return currentNode
    }
    if (!currentNode.elements) {
        return false
    }
    for (i = 0; i < currentNode.elements.length; i += 1) {
        // Search in the current child
        result = findNode(id, value, currentNode.elements[i])

        // Return the result if the node has been found
        if (result !== false) {
            return result
        }
    }

    // The node has not been found and we have no more options
    return false
}

const ids = []
let foundId = false
const translations = []
let finalTranslations = []

const rl = readline.createInterface({
    input: fs.createReadStream('./translations.txt'),
    crlfDelay: Infinity
})

rl.on('line', (line) => {
    if (line.indexOf('//') === 0) {
        const cleanLine = line
            .replace('//', '')
            .replace(/"/g, '')
            .replace(/ /g, '')
            .split(',')
            .map(id => id.replace(/\..*/, ''))
            .join(',')
        ids.push(cleanLine)
        foundId = true
    } else if (foundId) {
        translations.push(line.split('=')[0].replace(/"/g, '').replace(/ /g, ''))
        foundId = false
    }
}).on('close', () => {
    finalTranslations = ids.map((id, index) => ({ [id]: translations[index] }))
    args.forEach((path) => {
        console.log('paths', path)
        fs.readdirSync(path).forEach((file) => {
            if (file.indexOf('.xib') > 1 || file.indexOf('.storyboard') > 1) {
                const f = fs.readFileSync(path + file)
                const objFromFile = JSON.parse(convert.xml2json(f, options))
                finalTranslations.forEach((translation) => {
                    Object.keys(translation).forEach(key => key.split(',').forEach((id) => {
                        findNode(id, translation[key], objFromFile)
                    }))
                })

                const editedXml = convert.json2xml(JSON.stringify(objFromFile), options)
                fs.writeFileSync(path + file, editedXml)
            }
        })
    })
    process.exit(0)
})
