export const Logger = {
  Info: (message) => {
    console.log(`[INFO]: ${message}`)
  } ,
  Error: (message) => {
    console.error(`[ERROR]: ${message}`)
  }
}
