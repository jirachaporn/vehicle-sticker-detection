# from flask import Flask, request, jsonify
# from flask_cors import CORS
# import smtplib
# from email.message import EmailMessage
# import random

# import os
# from dotenv import load_dotenv

# load_dotenv()

# app = Flask(__name__)
# CORS(app)  # อนุญาตให้ Flutter call ข้าม origin

# EMAIL_ADDRESS = os.getenv('EMAIL_ADDRESS')
# EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD')

# @app.route('/send-email', methods=['POST'])
# def send_email():
#     data = request.get_json()
#     email = data['email']
#     otp = str(random.randint(1000, 9999))

#     msg = EmailMessage()
#     msg['Subject'] = 'OTP Verification'
#     msg['From'] = EMAIL_ADDRESS
#     msg['To'] = email
#     msg.set_content(f'Your OTP is: {otp}')

#     try:
#         with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
#             smtp.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
#             smtp.send_message(msg)

#         return jsonify({'message': 'Email sent', 'otp': otp}), 200
#     except Exception as e:
#         print(e)
#         return jsonify({'error': 'Failed to send email'}), 500

# if __name__ == '__main__':
#     app.run(host='127.0.0.1', port=5000, debug=True)

