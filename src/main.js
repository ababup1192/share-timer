import "regenerator-runtime/runtime";
import { Elm } from "./Main.elm";
let firebase = require("firebase");
require("firebase/firestore");

const firebaseConfig = {
  apiKey: "AIzaSyBCzn85hgBUTaZiy02NbPXVGE7j6Pb-5yE",
  authDomain: "share-timer-5905c.firebaseapp.com",
  databaseURL: "https://share-timer-5905c.firebaseio.com",
  projectId: "share-timer-5905c",
  storageBucket: "share-timer-5905c.appspot.com",
  messagingSenderId: "141282750555",
  appId: "1:141282750555:web:53503f67699daa474e4f7e",
  measurementId: "G-K5L1Y67VKC",
};
// Initialize Firebase
firebase.initializeApp(firebaseConfig);
firebase.analytics();
const db = firebase.firestore();

const app = Elm.Main.init({ node: document.getElementById("main") });

const shareTimers = "shareTimers";

Notification.requestPermission();

app.ports.createShareTimer.subscribe(async (data) => {
  const documentId = (await db.collection(shareTimers).add(data)).id;
  app.ports.getShareTimerId.send(documentId);
});

app.ports.accessShareTimer.subscribe((documentId) => {
  db.collection(shareTimers)
    .doc(documentId)
    .onSnapshot((shareTimerDoc) => {
      if (shareTimerDoc.exists) {
        app.ports.getShareTimer.send(shareTimerDoc.data());
      }
    });
});

app.ports.saveShareTimer.subscribe((data) => {
  db.collection(shareTimers).doc(data.shareTimerId).set(data);
});

app.ports.notifyTimeUp.subscribe((_) => {
  if (!("Notification" in window)) {
    alert("時間になりました。");
  } else if (Notification.permission === "granted") {
    new Notification("時間になりました。");
  }
});
