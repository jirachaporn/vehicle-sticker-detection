import cv2

cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)  # ลองเปลี่ยนเป็น 1 ถ้าไม่เห็นภาพ
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

if not cap.isOpened():
    print("❌ Cannot open camera")
    exit()

while True:
    ret, frame = cap.read()
    if not ret:
        print("❌ Cannot read frame")
        break

    cv2.imshow("Test Camera", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
