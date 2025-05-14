const functions = require('firebase-functions');
const tf = require('@tensorflow/tfjs-node');
const sharp = require('sharp');

exports.detectDisease = functions.https.onRequest(async (req, res) => {
  try {
    // Enable CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'POST');
      res.set('Access-Control-Allow-Headers', 'Content-Type');
      res.status(204).send('');
      return;
    }

    // Check request method
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const { image, isUrl } = req.body;
    
    if (!image) {
      res.status(400).send('No image provided');
      return;
    }

    // Load and preprocess image
    let imageBuffer;
    if (isUrl) {
      const response = await fetch(image);
      imageBuffer = await response.buffer();
    } else {
      imageBuffer = Buffer.from(image, 'base64');
    }

    // Resize image to model input size
    const preprocessedImage = await sharp(imageBuffer)
      .resize(640, 640, { fit: 'contain', background: { r: 0, g: 0, b: 0 } })
      .raw()
      .toBuffer();

    // Load model
    const model = await tf.node.loadSavedModel('model');
    
    // Convert image to tensor
    const tensor = tf.node.decodeImage(preprocessedImage, 3)
      .expandDims(0)
      .div(255.0);

    // Run inference
    const predictions = await model.predict(tensor);
    const data = await predictions.data();

    // Process results (similar to native implementation)
    let maxConfidence = 0;
    let maxClassIndex = 0;
    
    for (let i = 0; i < data.length; i += 85) {
      const confidence = data[i + 4];
      if (confidence > maxConfidence) {
        maxConfidence = confidence;
        maxClassIndex = i;
      }
    }

    // Get disease label
    const labels = ['algal-leaf', 'brown-blight', 'grey-blight']; // Update with your labels
    
    res.json({
      disease: labels[Math.floor(maxClassIndex / 85)],
      confidence: maxConfidence,
      bbox: [
        data[maxClassIndex],
        data[maxClassIndex + 1],
        data[maxClassIndex + 2],
        data[maxClassIndex + 3]
      ]
    });

    // Cleanup
    tensor.dispose();
    predictions.dispose();
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send('Internal Server Error: ' + error.message);
  }
}); 