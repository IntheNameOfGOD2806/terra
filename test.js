const array = [3, 5, 0, 6, 0, 7, 8, 9, 4]

const arrLength = array.length


const swap0 = (index, array) => {

    while (index < array.length - 1) {

        const s1 = array[index]

        const s2 = array[index + 1]

        array[index + 1] = s1
        array[index] = s2

        index++

    }

}
for (let i = 0; i < arrLength; i++) {
    if (array[i] === 0) {
        swap0(i, array)
    }

}
console.log(array)